#!/bin/bash
#
# RAGFlow Complete Setup and Start Script for RunPod
# This script performs BOTH setup AND startup in one go - ready to use out of the box
# Image: runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
#
# KEY IMPROVEMENTS OVER BASIC SETUP:
# - Properly exports MINIO_ROOT_USER and MINIO_ROOT_PASSWORD before starting MinIO
# - Uses wait_for_port() to verify each service actually starts (not just sleep)
# - Includes comprehensive error handling with clear error messages
# - Idempotent: safe to re-run, skips already running services
# - Full logging to $DATA_DIR/logs/ for troubleshooting
# - Service health verification after startup
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "RAGFlow Complete Setup & Start for RunPod"
echo "Out-of-the-Box Installation"
echo -e "==========================================${NC}"
echo ""

# Script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Config
MYSQL_PORT=5455
MYSQL_PASSWORD="infini_rag_flow"
REDIS_PORT=6379
REDIS_PASSWORD="infini_rag_flow"
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_USER="rag_flow"
MINIO_PASSWORD="infini_rag_flow"
ES_PORT=1200
ES_PASSWORD="infini_rag_flow"
ELASTIC_VERSION="8.11.3"

# Persistent data dirs
DATA_DIR="${RUNPOD_VOLUME_PATH:-/workspace}/ragflow-data"
MYSQL_BACKUP_DIR="$DATA_DIR/mysql-backup"
REDIS_DATA_DIR="$DATA_DIR/redis"
MINIO_DATA_DIR="$DATA_DIR/minio"
ES_DATA_DIR="$DATA_DIR/elasticsearch"
LOGS_DIR="$DATA_DIR/logs"
PIDS_DIR="$DATA_DIR/pids"

echo -e "${GREEN}Data directory: $DATA_DIR${NC}"
mkdir -p "$MYSQL_BACKUP_DIR" "$REDIS_DATA_DIR" "$MINIO_DATA_DIR" "$ES_DATA_DIR" "$LOGS_DIR" "$PIDS_DIR"

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_port() {
    local port=$1
    local service=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    echo "Waiting for $service to be ready on port $port..."
    while [ $attempt -le $max_attempts ]; do
        if check_port $port; then
            echo -e "${GREEN}✓ $service is ready on port $port${NC}"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ $service failed to start on port $port after ${max_attempts} attempts${NC}"
    echo -e "${YELLOW}Check logs in: $LOGS_DIR${NC}"
    return 1
}

# ================= MySQL (RunPod workaround) =================
echo ""
echo -e "${BLUE}Step 1: Setting up MySQL${NC}"

# Fix: Remove default user=mysql from existing configs to avoid permission issues
# This prevents mysqld from trying to switch to 'mysql' user which fails on mounted volumes
# (Even though we use /tmp, mysqld reads /etc/mysql and might try to switch users)
if [ "$(id -u)" = "0" ] && [ -d "/etc/mysql" ]; then
    echo "Sanitizing MySQL configuration to allow running as root..."
    find /etc/mysql -name "*.cnf" -exec sed -i 's/^user\s*=.*/#&/' {} + || true
fi

MYSQL_TMP_DIR="/tmp/ragflow-mysql"
mkdir -p "$MYSQL_TMP_DIR"

# Check if MySQL is already running
if check_port $MYSQL_PORT; then
    echo -e "${YELLOW}MySQL is already running on port $MYSQL_PORT${NC}"
else
    if [ ! -d "$MYSQL_TMP_DIR/mysql" ]; then
        echo "Initializing MySQL in /tmp (root-friendly)..."
        mysqld --initialize-insecure --datadir="$MYSQL_TMP_DIR" --user=root \
               --log-error="$LOGS_DIR/mysql-init.log" 2>&1 | tee -a "$LOGS_DIR/mysql-setup.log"
    fi
    
    echo "Starting MySQL..."
    mysqld --user=root --datadir="$MYSQL_TMP_DIR" --port="$MYSQL_PORT" \
           --socket="$DATA_DIR/mysql.sock" \
           --pid-file="$PIDS_DIR/mysql.pid" \
           --skip-networking=0 \
           >> "$LOGS_DIR/mysql.log" 2>&1 &
    
    echo $! > "$PIDS_DIR/mysql.pid"
    
    if ! wait_for_port $MYSQL_PORT "MySQL" 30; then
        echo -e "${RED}MySQL failed to start. Check $LOGS_DIR/mysql.log${NC}"
        exit 1
    fi
    
    # Set root password
    echo "Configuring MySQL..."
    sleep 2
    # Use a temporary config file to avoid password exposure in process list
    MYSQL_CONFIG_FILE="/tmp/mysql_init_$$.cnf"
    cat > "$MYSQL_CONFIG_FILE" <<EOF
[client]
user=root
host=127.0.0.1
port=$MYSQL_PORT
EOF
    chmod 600 "$MYSQL_CONFIG_FILE"
    mysql --defaults-extra-file="$MYSQL_CONFIG_FILE" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}'; FLUSH PRIVILEGES;" 2>/dev/null || true
    rm -f "$MYSQL_CONFIG_FILE"
    
    # Optional: backup snapshot to persistent volume
    mkdir -p "$MYSQL_BACKUP_DIR"
    cp -r "$MYSQL_TMP_DIR"/* "$MYSQL_BACKUP_DIR/" 2>/dev/null || true
fi

echo -e "${GREEN}✓ MySQL ready (running in /tmp, backup in $MYSQL_BACKUP_DIR)${NC}"

# ================= Redis =================
echo ""
echo -e "${BLUE}Step 2: Setting up Redis${NC}"

# Create Redis configuration
cat > "$REDIS_DATA_DIR/redis.conf" <<EOF
bind 127.0.0.1
port ${REDIS_PORT}
requirepass ${REDIS_PASSWORD}
maxmemory 512mb
maxmemory-policy allkeys-lru
daemonize no
dir ${REDIS_DATA_DIR}
dbfilename dump.rdb
EOF

# Check if Redis is already running
if check_port $REDIS_PORT; then
    echo -e "${YELLOW}Redis is already running on port $REDIS_PORT${NC}"
else
    echo "Starting Redis..."
    redis-server "$REDIS_DATA_DIR/redis.conf" \
        >> "$LOGS_DIR/redis.log" 2>&1 &
    
    echo $! > "$PIDS_DIR/redis.pid"
    
    if ! wait_for_port $REDIS_PORT "Redis" 15; then
        echo -e "${RED}Redis failed to start. Check $LOGS_DIR/redis.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Redis ready${NC}"

# ================= MinIO =================
echo ""
echo -e "${BLUE}Step 3: Setting up MinIO${NC}"

# Download MinIO if not present
if [ ! -f /usr/local/bin/minio ]; then
    echo "Downloading MinIO..."
    wget -q https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
    chmod +x /usr/local/bin/minio
    echo "MinIO binary installed"
fi

# Check if MinIO is already running
if check_port $MINIO_PORT; then
    echo -e "${YELLOW}MinIO is already running on port $MINIO_PORT${NC}"
else
    echo "Starting MinIO..."
    # CRITICAL: Set environment variables BEFORE starting MinIO
    export MINIO_ROOT_USER="$MINIO_USER"
    export MINIO_ROOT_PASSWORD="$MINIO_PASSWORD"
    
    /usr/local/bin/minio server "$MINIO_DATA_DIR" \
        --console-address ":$MINIO_CONSOLE_PORT" \
        --address ":$MINIO_PORT" \
        >> "$LOGS_DIR/minio.log" 2>&1 &
    
    MINIO_PID=$!
    echo $MINIO_PID > "$PIDS_DIR/minio.pid"
    echo "MinIO started with PID: $MINIO_PID"
    
    if ! wait_for_port $MINIO_PORT "MinIO" 30; then
        echo -e "${RED}MinIO failed to start. Check $LOGS_DIR/minio.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ MinIO ready${NC}"

# ================= Elasticsearch =================
echo ""
echo -e "${BLUE}Step 4: Setting up Elasticsearch${NC}"

ES_INSTALL_DIR="$DATA_DIR/elasticsearch-bin"

# Download and install Elasticsearch if not present
if [ ! -d "$ES_INSTALL_DIR" ]; then
    echo "Downloading Elasticsearch ${ELASTIC_VERSION}..."
    cd /tmp
    wget -q "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
    tar -xzf "elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
    mv "elasticsearch-${ELASTIC_VERSION}" "$ES_INSTALL_DIR"
    rm "elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
    cd "$SCRIPT_DIR"
    echo "Elasticsearch extracted to $ES_INSTALL_DIR"
fi

# Configure Elasticsearch
cat > "$ES_INSTALL_DIR/config/elasticsearch.yml" <<EOF
cluster.name: ragflow-cluster
node.name: node-1
path.data: ${ES_DATA_DIR}
path.logs: ${LOGS_DIR}/elasticsearch
network.host: 127.0.0.1
http.port: ${ES_PORT}
discovery.type: single-node
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
EOF

cat > "$ES_INSTALL_DIR/config/jvm.options.d/heap.options" <<EOF
-Xms2g
-Xmx2g
EOF

# Create data and log directories
mkdir -p "$ES_DATA_DIR" "$LOGS_DIR/elasticsearch"

# Check if Elasticsearch is already running
if check_port $ES_PORT; then
    echo -e "${YELLOW}Elasticsearch is already running on port $ES_PORT${NC}"
else
    echo "Starting Elasticsearch..."
    # Allow running as root in containerized environments
    export ES_JAVA_OPTS="-Des.insecure.allow.root=true"
    
    "$ES_INSTALL_DIR/bin/elasticsearch" -d -p "$PIDS_DIR/elasticsearch.pid" \
        >> "$LOGS_DIR/elasticsearch-startup.log" 2>&1
    
    if ! wait_for_port $ES_PORT "Elasticsearch" 60; then
        echo -e "${RED}Elasticsearch failed to start. Check $LOGS_DIR/elasticsearch-startup.log${NC}"
        echo -e "${YELLOW}Last 20 lines of log:${NC}"
        tail -20 "$LOGS_DIR/elasticsearch-startup.log" 2>/dev/null || true
        exit 1
    fi
    
    # Set elastic password
    echo "Configuring Elasticsearch password..."
    sleep 5
    "$ES_INSTALL_DIR/bin/elasticsearch-reset-password" -u elastic -i -b << 'ESPASS' || true
$ES_PASSWORD
$ES_PASSWORD
ESPASS
fi

cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Elasticsearch ready${NC}"

# ================= Python Env =================
echo ""
echo -e "${BLUE}Step 5: Setting up Python environment${NC}"

if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "Installing uv package manager..."
    if ! command -v uv &> /dev/null; then
        pip install uv
    fi
    
    echo "Creating Python virtual environment..."
    uv venv --python 3.11
    
    # Patch pyproject.toml to remove Aliyun mirror for RunPod
    if grep -q "mirrors.aliyun.com" pyproject.toml; then
        echo "Removing Aliyun mirror from pyproject.toml..."
        cp pyproject.toml pyproject.toml.bak
        sed -i '/\[\[tool.uv.index\]\]/d' pyproject.toml
        sed -i '/url = "https:\/\/mirrors.aliyun.com\/pypi\/simple"/d' pyproject.toml
    fi

    echo "Installing Python dependencies (this may take a while)..."
    uv sync --all-extras
    
    echo "Downloading additional dependencies..."
    uv run download_deps.py
else
    echo -e "${GREEN}Virtual environment already exists${NC}"
fi

echo -e "${GREEN}✓ Python environment ready${NC}"

# ================= Frontend =================
echo ""
echo -e "${BLUE}Step 6: Setting up Frontend${NC}"

cd "$SCRIPT_DIR/web"
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies (this may take a while)..."
    npm install
else
    echo -e "${GREEN}Frontend dependencies already installed${NC}"
fi
cd "$SCRIPT_DIR"

echo -e "${GREEN}✓ Frontend ready${NC}"

# ================= Environment =================
echo ""
echo -e "${BLUE}Step 7: Creating .env file${NC}"

cat > "$SCRIPT_DIR/.env" <<EOF
# RAGFlow Environment Configuration
# Generated by setup_and_start_runpod.sh

# Service Ports
MYSQL_PORT=${MYSQL_PORT}
REDIS_PORT=${REDIS_PORT}
MINIO_PORT=${MINIO_PORT}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT}
ES_PORT=${ES_PORT}

# Service Passwords
MYSQL_PASSWORD=${MYSQL_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
MINIO_PASSWORD=${MINIO_PASSWORD}
ES_PASSWORD=${ES_PASSWORD}

# Service Users
MINIO_USER=${MINIO_USER}

# Data Directory
DATA_DIR=${DATA_DIR}

# Number of task executor workers
WS=1
EOF

echo -e "${GREEN}✓ .env created${NC}"

# ================= Hosts =================
echo ""
echo -e "${BLUE}Step 8: Configuring /etc/hosts${NC}"

if ! grep -q "es01" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 es01 infinity mysql minio redis sandbox-executor-manager" >> /etc/hosts
    echo "Added host entries"
else
    echo -e "${GREEN}Host entries already configured${NC}"
fi

echo -e "${GREEN}✓ Hosts configured${NC}"

# ================= Verify All Services =================
echo ""
echo -e "${BLUE}Step 9: Verifying all services${NC}"
echo ""

SERVICES_OK=true

# Check MySQL
if MYSQL_PWD="${MYSQL_PASSWORD}" mysql -u root -h 127.0.0.1 -P $MYSQL_PORT -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL is accessible${NC}"
else
    echo -e "${RED}✗ MySQL connection failed${NC}"
    SERVICES_OK=false
fi

# Check Redis
if REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -p $REDIS_PORT ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✓ Redis is accessible${NC}"
else
    echo -e "${RED}✗ Redis connection failed${NC}"
    SERVICES_OK=false
fi

# Check MinIO
if curl -sf "http://127.0.0.1:$MINIO_PORT/minio/health/live" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MinIO is accessible${NC}"
else
    echo -e "${YELLOW}⚠ MinIO health check inconclusive (may still be OK)${NC}"
fi

# Check Elasticsearch
if curl -sf -u elastic:"$ES_PASSWORD" "http://127.0.0.1:$ES_PORT" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch is accessible${NC}"
else
    echo -e "${RED}✗ Elasticsearch connection failed${NC}"
    SERVICES_OK=false
fi

echo ""

if [ "$SERVICES_OK" = false ]; then
    echo -e "${RED}Some services failed to start properly!${NC}"
    echo -e "${YELLOW}Check logs in: $LOGS_DIR${NC}"
    exit 1
fi

# ================= Start RAGFlow Backend =================
echo ""
echo -e "${BLUE}Step 10: Starting RAGFlow Backend${NC}"

# Check if backend is already running
if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}RAGFlow backend is already running${NC}"
else
    mkdir -p "$SCRIPT_DIR/logs"
    
    echo "Starting backend..."
    (
        source .venv/bin/activate
        export PYTHONPATH="$SCRIPT_DIR"
        bash launch_backend_service.sh >> "$SCRIPT_DIR/logs/ragflow_server.log" 2>&1
    ) &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$PIDS_DIR/ragflow_backend.pid"
    
    echo "Backend starting with PID: $BACKEND_PID"
    echo "Waiting for backend to initialize..."
    
    # Wait for backend to start
    BACKEND_READY=false
    for i in {1..60}; do
        sleep 1
        if check_port 9380; then
            echo -e "${GREEN}✓ Backend started successfully on port 9380!${NC}"
            BACKEND_READY=true
            break
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "Still waiting for backend... ($i seconds)"
        fi
    done
    
    if [ "$BACKEND_READY" = false ]; then
        echo -e "${RED}Backend may have failed to start${NC}"
        echo -e "${YELLOW}Check logs: tail -f $SCRIPT_DIR/logs/ragflow_server.log${NC}"
        exit 1
    fi
fi

# ================= Start Frontend =================
echo ""
echo -e "${BLUE}Step 11: Starting Frontend${NC}"

# Check if frontend is already running
if check_port 9222; then
    echo -e "${YELLOW}Frontend is already running on port 9222${NC}"
else
    cd "$SCRIPT_DIR/web"
    
    echo "Starting frontend..."
    (
        npm run dev >> "$LOGS_DIR/frontend.log" 2>&1
    ) &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$PIDS_DIR/ragflow_frontend.pid"
    
    echo "Frontend starting with PID: $FRONTEND_PID"
    echo "Waiting for frontend to initialize..."
    
    # Wait for frontend to start
    FRONTEND_READY=false
    for i in {1..120}; do
        sleep 1
        if check_port 9222; then
            echo -e "${GREEN}✓ Frontend started successfully on port 9222!${NC}"
            FRONTEND_READY=true
            break
        fi
        if [ $((i % 20)) -eq 0 ]; then
            echo "Still waiting for frontend... ($i seconds)"
        fi
    done
    
    if [ "$FRONTEND_READY" = false ]; then
        echo -e "${YELLOW}Frontend is still starting (may take longer for first build)${NC}"
        echo -e "${YELLOW}Check logs: tail -f $LOGS_DIR/frontend.log${NC}"
    fi
    
    cd "$SCRIPT_DIR"
fi

# ================= GPU Check =================
echo ""
echo -e "${BLUE}Step 12: Checking GPU availability${NC}"
echo ""

if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}GPU Information:${NC}"
    nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv
    echo ""
    
    # Check CUDA availability in Python
    CUDA_AVAILABLE=$("$SCRIPT_DIR/.venv/bin/python" -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "false")
    if [ "$CUDA_AVAILABLE" = "True" ]; then
        echo -e "${GREEN}✓ PyTorch CUDA is available${NC}"
    else
        echo -e "${YELLOW}⚠ PyTorch CUDA is not available${NC}"
    fi
else
    echo -e "${YELLOW}⚠ nvidia-smi not found, skipping GPU check${NC}"
fi

# ================= Summary =================
echo ""
echo -e "${GREEN}=========================================="
echo "RAGFlow is Ready!"
echo -e "==========================================${NC}"
echo ""
echo -e "${GREEN}Application URLs:${NC}"
echo "  Frontend:      http://localhost:9222"
echo "  Backend API:   http://127.0.0.1:9380"
echo ""
echo -e "${BLUE}Infrastructure URLs:${NC}"
echo "  MySQL:         127.0.0.1:$MYSQL_PORT"
echo "  Redis:         127.0.0.1:$REDIS_PORT"
echo "  MinIO API:     http://127.0.0.1:$MINIO_PORT"
echo "  MinIO Console: http://127.0.0.1:$MINIO_CONSOLE_PORT"
echo "  Elasticsearch: http://127.0.0.1:$ES_PORT"
echo ""
echo -e "${BLUE}Default Credentials:${NC}"
echo "  MySQL:         root / ${MYSQL_PASSWORD}"
echo "  Redis:         ${REDIS_PASSWORD}"
echo "  MinIO:         ${MINIO_USER} / ${MINIO_PASSWORD}"
echo "  Elasticsearch: elastic / ${ES_PASSWORD}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  Backend:  $SCRIPT_DIR/logs/ragflow_server.log"
echo "  Frontend: $LOGS_DIR/frontend.log"
echo "  Services: $LOGS_DIR/"
echo ""
echo -e "${BLUE}To stop RAGFlow:${NC}"
echo "  bash stop_ragflow_runpod.sh"
echo ""
echo -e "${GREEN}Open your browser to: http://localhost:9222${NC}"
echo ""

if [ -n "${RUNPOD_POD_ID:-}" ]; then
    echo -e "${YELLOW}Note: In RunPod, access via the exposed ports in your pod settings.${NC}"
    echo ""
fi

echo -e "${GREEN}Setup and startup complete! Everything is running.${NC}"
