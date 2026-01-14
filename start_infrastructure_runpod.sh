#!/bin/bash
#
# RAGFlow Infrastructure Startup Script for RunPod
# Starts all required infrastructure services (MySQL, Redis, MinIO, Elasticsearch)
# without requiring sudo or systemd.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Infrastructure Startup for RunPod"
echo -e "==========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    echo -e "${RED}Error: .env file not found. Run setup_runpod.sh first.${NC}"
    exit 1
fi

# Configuration defaults
MYSQL_PORT=${MYSQL_PORT:-5455}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"infini_rag_flow"}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-"infini_rag_flow"}
MINIO_PORT=${MINIO_PORT:-9000}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-9001}
MINIO_USER=${MINIO_USER:-"rag_flow"}
MINIO_PASSWORD=${MINIO_PASSWORD:-"infini_rag_flow"}
ES_PORT=${ES_PORT:-1200}
ES_PASSWORD=${ES_PASSWORD:-"infini_rag_flow"}

DATA_DIR="${DATA_DIR:-${RUNPOD_VOLUME_PATH:-/workspace}/ragflow-data}"
MYSQL_DATA_DIR="$DATA_DIR/mysql"
REDIS_DATA_DIR="$DATA_DIR/redis"
MINIO_DATA_DIR="$DATA_DIR/minio"
ES_DATA_DIR="$DATA_DIR/elasticsearch"
LOGS_DIR="$DATA_DIR/logs"
PIDS_DIR="$DATA_DIR/pids"

# Create directories
mkdir -p "$LOGS_DIR" "$PIDS_DIR"

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
    
    while [ $attempt -le $max_attempts ]; do
        if check_port $port; then
            echo -e "${GREEN}✓ $service is ready on port $port${NC}"
            return 0
        fi
        echo "Waiting for $service... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ $service failed to start on port $port${NC}"
    return 1
}

# ==================== Start MySQL ====================
echo -e "${BLUE}Starting MySQL...${NC}"

if check_port $MYSQL_PORT; then
    echo -e "${YELLOW}MySQL is already running on port $MYSQL_PORT${NC}"
else
    # Ensure data directory exists
    mkdir -p "$MYSQL_DATA_DIR"
    
    # Determine which user to run MySQL as
    if [ "$(id -u)" = "0" ]; then
        # Running as root - use mysql user for security
        echo "Running as root, starting MySQL with mysql user..."
        chown -R mysql:mysql "$MYSQL_DATA_DIR" "$LOGS_DIR" 2>/dev/null || true
        MYSQL_USER="--user=mysql"
    else
        # Running as non-root user
        echo "Running as non-root user ($(whoami)), starting MySQL with current user..."
        MYSQL_USER=""
    fi
    
    # Start MySQL in background
    mysqld \
        $MYSQL_USER \
        --datadir="$MYSQL_DATA_DIR" \
        --port="$MYSQL_PORT" \
        --socket="$DATA_DIR/mysql.sock" \
        --pid-file="$PIDS_DIR/mysql.pid" \
        --log-error="$LOGS_DIR/mysql.log" \
        >> "$LOGS_DIR/mysql-stdout.log" 2>&1 &
    
    echo $! > "$PIDS_DIR/mysql.pid"
    
    wait_for_port $MYSQL_PORT "MySQL"
    
    # Set root password and create database if needed
    sleep 2
    if mysql -u root -h 127.0.0.1 -P $MYSQL_PORT -e "SELECT 1" 2>/dev/null; then
        echo "Setting MySQL root password..."
        mysql -u root -h 127.0.0.1 -P $MYSQL_PORT -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" 2>/dev/null || true
        mysql -u root -p"${MYSQL_PASSWORD}" -h 127.0.0.1 -P $MYSQL_PORT -e "CREATE DATABASE IF NOT EXISTS rag_flow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    fi
fi

# ==================== Start Redis ====================
echo -e "${BLUE}Starting Redis...${NC}"

if check_port $REDIS_PORT; then
    echo -e "${YELLOW}Redis is already running on port $REDIS_PORT${NC}"
else
    # Start Redis in background
    redis-server /etc/redis/redis-ragflow.conf \
        >> "$LOGS_DIR/redis.log" 2>&1 &
    
    echo $! > "$PIDS_DIR/redis.pid"
    
    wait_for_port $REDIS_PORT "Redis"
fi

# ==================== Start MinIO ====================
echo -e "${BLUE}Starting MinIO...${NC}"

if check_port $MINIO_PORT; then
    echo -e "${YELLOW}MinIO is already running on port $MINIO_PORT${NC}"
else
    # Start MinIO in background
    MINIO_ROOT_USER="$MINIO_USER" \
    MINIO_ROOT_PASSWORD="$MINIO_PASSWORD" \
    /usr/local/bin/minio server \
        --console-address ":$MINIO_CONSOLE_PORT" \
        --address ":$MINIO_PORT" \
        "$MINIO_DATA_DIR" \
        >> "$LOGS_DIR/minio.log" 2>&1 &
    
    echo $! > "$PIDS_DIR/minio.pid"
    
    wait_for_port $MINIO_PORT "MinIO"
fi

# ==================== Start Elasticsearch ====================
echo -e "${BLUE}Starting Elasticsearch...${NC}"

if check_port $ES_PORT; then
    echo -e "${YELLOW}Elasticsearch is already running on port $ES_PORT${NC}"
else
    ES_INSTALL_DIR="/opt/elasticsearch"
    
    if [ ! -d "$ES_INSTALL_DIR" ]; then
        echo -e "${RED}Elasticsearch not found at $ES_INSTALL_DIR. Run setup_runpod.sh first.${NC}"
        exit 1
    fi
    
    # Create es user directories if needed
    mkdir -p "$ES_DATA_DIR" "$LOGS_DIR/elasticsearch"
    
    # Create a non-root user for Elasticsearch if running as root
    if [ "$(id -u)" = "0" ]; then
        # Create elasticsearch user if not exists (required for ES security)
        if ! id -u elasticsearch &>/dev/null; then
            echo "Creating elasticsearch system user..."
            useradd -r -s /bin/false elasticsearch 2>/dev/null || {
                echo -e "${YELLOW}Warning: Could not create elasticsearch user, using root${NC}"
            }
        fi
        
        # Set ownership if user exists
        if id -u elasticsearch &>/dev/null; then
            chown -R elasticsearch:elasticsearch "$ES_INSTALL_DIR" "$ES_DATA_DIR" "$LOGS_DIR/elasticsearch"
            
            # Start Elasticsearch as elasticsearch user
            su elasticsearch -s /bin/bash -c "$ES_INSTALL_DIR/bin/elasticsearch -d -p $PIDS_DIR/elasticsearch.pid" \
                >> "$LOGS_DIR/elasticsearch.log" 2>&1
        else
            # Start Elasticsearch directly if user creation failed
            "$ES_INSTALL_DIR/bin/elasticsearch" -d -p "$PIDS_DIR/elasticsearch.pid" \
                >> "$LOGS_DIR/elasticsearch.log" 2>&1
        fi
    else
        # Start Elasticsearch directly
        "$ES_INSTALL_DIR/bin/elasticsearch" -d -p "$PIDS_DIR/elasticsearch.pid" \
            >> "$LOGS_DIR/elasticsearch.log" 2>&1
    fi
    
    wait_for_port $ES_PORT "Elasticsearch" 60
    
    # Set elastic password if needed using environment variable approach
    sleep 5
    echo "Setting Elasticsearch password..."
    # Use non-interactive mode with auto-generated password first, then change it
    ES_BOOTSTRAP_PASSWORD="$ES_PASSWORD" "$ES_INSTALL_DIR/bin/elasticsearch-reset-password" \
        -u elastic -i -b -f 2>/dev/null << ESPASS || true
$ES_PASSWORD
$ES_PASSWORD
ESPASS
fi

# ==================== Verify Services ====================
echo ""
echo -e "${BLUE}Verifying services...${NC}"
echo ""

SERVICES_OK=true

# Check MySQL
if mysql -u root -p"${MYSQL_PASSWORD}" -h 127.0.0.1 -P $MYSQL_PORT -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL is accessible${NC}"
else
    echo -e "${RED}✗ MySQL connection failed${NC}"
    SERVICES_OK=false
fi

# Check Redis
if redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✓ Redis is accessible${NC}"
else
    echo -e "${RED}✗ Redis connection failed${NC}"
    SERVICES_OK=false
fi

# Check MinIO
if curl -sf "http://127.0.0.1:$MINIO_PORT/minio/health/live" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MinIO is accessible${NC}"
else
    echo -e "${YELLOW}⚠ MinIO health check inconclusive${NC}"
fi

# Check Elasticsearch
if curl -sf -u elastic:"$ES_PASSWORD" "http://127.0.0.1:$ES_PORT" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch is accessible${NC}"
else
    echo -e "${RED}✗ Elasticsearch connection failed${NC}"
    SERVICES_OK=false
fi

echo ""

if [ "$SERVICES_OK" = true ]; then
    echo -e "${GREEN}=========================================="
    echo "All infrastructure services are running!"
    echo -e "==========================================${NC}"
else
    echo -e "${RED}=========================================="
    echo "Some services failed to start!"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "${YELLOW}Check logs in: $LOGS_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Service Endpoints:${NC}"
echo "  MySQL:         127.0.0.1:$MYSQL_PORT"
echo "  Redis:         127.0.0.1:$REDIS_PORT"
echo "  MinIO API:     http://127.0.0.1:$MINIO_PORT"
echo "  MinIO Console: http://127.0.0.1:$MINIO_CONSOLE_PORT"
echo "  Elasticsearch: http://127.0.0.1:$ES_PORT"
echo ""
echo -e "${BLUE}Logs:${NC} $LOGS_DIR"
echo -e "${BLUE}PIDs:${NC} $PIDS_DIR"
echo ""
