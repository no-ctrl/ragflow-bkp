#!/bin/bash
#
# RAGFlow Setup Script for RunPod
# Designed for runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04 image
#
# This script installs all required dependencies and infrastructure services
# without requiring sudo (runs as root in RunPod containers).
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Setup for RunPod"
echo -e "==========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration (matching existing service_conf.yaml defaults)
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

# Data directories (using workspace for persistence in RunPod)
DATA_DIR="${RUNPOD_VOLUME_PATH:-/workspace}/ragflow-data"
MYSQL_DATA_DIR="$DATA_DIR/mysql"
REDIS_DATA_DIR="$DATA_DIR/redis"
MINIO_DATA_DIR="$DATA_DIR/minio"
ES_DATA_DIR="$DATA_DIR/elasticsearch"
LOGS_DIR="$DATA_DIR/logs"

echo -e "${GREEN}Data directory: $DATA_DIR${NC}"
echo ""

# Check if running as root or non-root
if [ "$(id -u)" = "0" ]; then
    echo -e "${GREEN}Running as root${NC}"
    SUDO=""
else
    echo -e "${YELLOW}Running as non-root user ($(whoami))${NC}"
    echo -e "${YELLOW}Some operations may require sudo privileges${NC}"
    SUDO="sudo"
fi
echo ""

# Create data directories
mkdir -p "$MYSQL_DATA_DIR" "$REDIS_DATA_DIR" "$MINIO_DATA_DIR" "$ES_DATA_DIR" "$LOGS_DIR"

# ==================== Step 1: System Dependencies ====================
echo -e "${BLUE}Step 1: Installing system dependencies${NC}"
echo ""

# Update package list
$SUDO apt-get update

# Install required packages
$SUDO apt-get install -y \
    wget \
    curl \
    lsof \
    gnupg \
    apt-transport-https \
    libjemalloc-dev \
    pkg-config \
    mysql-server \
    redis-server \
    default-jdk \
    unixodbc-dev \
    python3-dev \
    libicu-dev

# Install Node.js 20.x
echo "Setting up Node.js 20.x repository..."
curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash -
$SUDO apt-get install -y nodejs

echo -e "${GREEN}✓ System dependencies installed${NC}"
echo ""

# ==================== Step 2: Configure MySQL ====================
echo -e "${BLUE}Step 2: Setting up MySQL${NC}"
echo ""

# Configure MySQL to use custom data directory and port
$SUDO mkdir -p /etc/mysql/mysql.conf.d

# Fix: Remove default user=mysql from existing configs to avoid permission issues when running as root
# This prevents mysqld from trying to switch to 'mysql' user which fails on mounted volumes
if [ -d "/etc/mysql" ]; then
    echo "Sanitizing MySQL configuration to allow running as root..."
    $SUDO find /etc/mysql -name "*.cnf" -exec sed -i 's/^user\s*=.*/#&/' {} + || true
fi

$SUDO tee /etc/mysql/mysql.conf.d/ragflow.cnf > /dev/null <<EOF
[mysqld]
user = root
datadir = ${MYSQL_DATA_DIR}
port = ${MYSQL_PORT}
max_connections = 1000
max_allowed_packet = 1073741824
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-host-cache
skip-name-resolve
bind-address = 127.0.0.1
innodb_use_native_aio = 0
EOF

# Initialize MySQL if data directory is empty
if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
    echo "Initializing MySQL data directory..."
    
    # Ensure data directory exists
    mkdir -p "$MYSQL_DATA_DIR" "$LOGS_DIR"
    
    # Detect if running as root or non-root user
    if [ "$(id -u)" = "0" ]; then
        # Running as root in containerized environment (e.g., RunPod)
        # Skip ownership changes and initialize directly as root
        echo "Running as root (containerized environment)"
        echo "Initializing MySQL with root user (no ownership changes)..."
        
        # Initialize MySQL as root without attempting ownership changes
        mysqld --initialize-insecure --user=root --datadir="$MYSQL_DATA_DIR" \
            --log-error="$LOGS_DIR/mysql-init.log"
    else
        # Running as non-root user - use current user
        echo "Running as non-root user ($(whoami)), initializing MySQL with current user..."
        
        # Initialize without --user flag (uses current user)
        mysqld --initialize-insecure --datadir="$MYSQL_DATA_DIR" \
            --log-error="$LOGS_DIR/mysql-init.log"
    fi
    
    echo "MySQL initialization log: $LOGS_DIR/mysql-init.log"
fi

echo -e "${GREEN}✓ MySQL configured${NC}"
echo ""

# ==================== Step 3: Configure Redis ====================
echo -e "${BLUE}Step 3: Setting up Redis${NC}"
echo ""

# Create Redis configuration
$SUDO tee /etc/redis/redis-ragflow.conf > /dev/null <<EOF
bind 127.0.0.1
port ${REDIS_PORT}
requirepass ${REDIS_PASSWORD}
maxmemory 512mb
maxmemory-policy allkeys-lru
daemonize no
dir ${REDIS_DATA_DIR}
dbfilename dump.rdb
EOF

echo -e "${GREEN}✓ Redis configured${NC}"
echo ""

# ==================== Step 4: Install MinIO ====================
echo -e "${BLUE}Step 4: Setting up MinIO${NC}"
echo ""

# Download MinIO if not present
if [ ! -f /usr/local/bin/minio ]; then
    echo "Downloading MinIO..."
    $SUDO wget -q https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
    $SUDO chmod +x /usr/local/bin/minio
fi

echo -e "${GREEN}✓ MinIO installed${NC}"
echo ""

# ==================== Step 5: Install Elasticsearch ====================
echo -e "${BLUE}Step 5: Setting up Elasticsearch${NC}"
echo ""

ES_INSTALL_DIR="/opt/elasticsearch"
if [ ! -d "$ES_INSTALL_DIR" ]; then
    echo "Downloading Elasticsearch ${ELASTIC_VERSION}..."
    cd /tmp
    wget -q "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
    tar -xzf "elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
    $SUDO mv "elasticsearch-${ELASTIC_VERSION}" "$ES_INSTALL_DIR"
    rm "elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz"
fi

# Configure Elasticsearch
$SUDO tee "$ES_INSTALL_DIR/config/elasticsearch.yml" > /dev/null <<EOF
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
cluster.routing.allocation.disk.watermark.low: 5gb
cluster.routing.allocation.disk.watermark.high: 3gb
cluster.routing.allocation.disk.watermark.flood_stage: 2gb
EOF

# Configure JVM heap size
$SUDO tee "$ES_INSTALL_DIR/config/jvm.options.d/heap.options" > /dev/null <<EOF
-Xms2g
-Xmx2g
EOF

cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Elasticsearch installed${NC}"
echo ""

# ==================== Step 6: Python Environment ====================
echo -e "${BLUE}Step 6: Setting up Python environment${NC}"
echo ""

# Create virtual environment and install dependencies
VENV_DIR="/opt/ragflow_venv"
echo "Creating Python virtual environment at $VENV_DIR..."

# Forcefully remove old environment to ensure a clean, non-interactive setup
if [ -d "$VENV_DIR" ]; then
    echo "Removing existing virtual environment at $VENV_DIR..."
    $SUDO rm -rf "$VENV_DIR"
fi

export UV_HTTP_TIMEOUT=300
echo "Creating new virtual environment using python3 -m venv..."
$SUDO python3 -m venv "$VENV_DIR"

echo "Installing uv into the virtual environment..."
# Ensure the venv and pip exist before trying to use them
if [ ! -f "$VENV_DIR/bin/pip" ]; then
    echo -e "${RED}Error: pip not found in virtual environment. Setup failed.${NC}"
    exit 1
fi
$SUDO "$VENV_DIR/bin/pip" install uv

echo "Installing Python dependencies..."

# Patch pyproject.toml to remove Aliyun mirror for RunPod (to ensure reliable downloads)
if grep -q "mirrors.aliyun.com" pyproject.toml; then
    echo "Removing Aliyun mirror from pyproject.toml for RunPod..."
    # Backup the original file
    cp pyproject.toml pyproject.toml.bak
    # Remove the tool.uv.index section and the url line
    # Using sed to delete the lines containing the mirror config
    sed -i '/\[\[tool.uv.index\]\]/d' pyproject.toml
    sed -i '/url = "https:\/\/mirrors.aliyun.com\/pypi\/simple"/d' pyproject.toml

    # Also remove uv.lock if it exists to prevent using Aliyun mirrors from the lockfile
    # This forces uv to resolve dependencies again using the default PyPI
    if [ -f "uv.lock" ]; then
        echo "Removing uv.lock to ensure clean resolution without Aliyun mirrors..."
        rm uv.lock
    fi
fi

# We need to set VIRTUAL_ENV and use --active to ensure uv installs into our custom venv location
# instead of creating a new .venv in the current directory
export VIRTUAL_ENV="$VENV_DIR"
$SUDO "$VENV_DIR/bin/uv" sync --active --all-extras

echo -e "${GREEN}✓ Python environment ready${NC}"
echo ""

# ==================== Step 7: Download additional dependencies ====================
echo -e "${BLUE}Step 7: Downloading additional dependencies${NC}"
echo ""

# Create local directories for dependencies
LOCAL_DEPS_DIR="/opt/ragflow/deps"
LOCAL_HF_DIR="/opt/ragflow/huggingface"
LOCAL_NLTK_DIR="/opt/ragflow/nltk"

$SUDO mkdir -p "$LOCAL_DEPS_DIR" "$LOCAL_HF_DIR" "$LOCAL_NLTK_DIR"

# Download deps using uv run to ensure script dependencies are met
# We download to local directories to optimize performance
$SUDO "$VENV_DIR/bin/uv" run download_deps.py \
    --model-dir "$LOCAL_HF_DIR" \
    --nltk-dir "$LOCAL_NLTK_DIR" \
    --deps-dir "$LOCAL_DEPS_DIR"

# Ensure the application can find the HuggingFace models
# The app looks in ~/.ragflow by default
RAGFLOW_HOME="/root/.ragflow"
if [ ! -d "$RAGFLOW_HOME" ]; then
    $SUDO mkdir -p "$(dirname "$RAGFLOW_HOME")"
    $SUDO ln -s "$LOCAL_HF_DIR" "$RAGFLOW_HOME"
fi

echo -e "${GREEN}✓ Additional dependencies downloaded${NC}"
echo ""

# ==================== Step 8: Frontend Dependencies ====================
echo -e "${BLUE}Step 8: Setting up frontend${NC}"
echo ""

cd "$SCRIPT_DIR/web"

# Create a directory for node_modules on the local disk
NODE_MODULES_DIR="/opt/ragflow_node_modules"
echo "Creating Node.js modules directory at $NODE_MODULES_DIR"
$SUDO mkdir -p "$NODE_MODULES_DIR"

# Create a symbolic link to the local directory
if [ ! -L "node_modules" ]; then
    ln -s "$NODE_MODULES_DIR" "node_modules"
fi

# Install npm dependencies
npm install

cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
echo ""

# ==================== Step 9: Create .env file ====================
echo -e "${BLUE}Step 9: Creating environment configuration${NC}"
echo ""

# Create .env file for launch_backend_service.sh
cat > "$SCRIPT_DIR/.env" <<EOF
# RAGFlow Environment Configuration for RunPod
# Generated by setup_runpod.sh

# Service Ports
MYSQL_PORT=${MYSQL_PORT}
REDIS_PORT=${REDIS_PORT}
MINIO_PORT=${MINIO_PORT}
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

# Local Dependencies
NLTK_DATA=/opt/ragflow/nltk
TIKTOKEN_CACHE_DIR=/opt/ragflow/deps
TIKA_SERVER_JAR=/opt/ragflow/deps/tika-server-standard-3.0.0.jar
EOF

echo -e "${GREEN}✓ Environment configuration created${NC}"
echo ""

# ==================== Step 10: Add hosts entries ====================
echo -e "${BLUE}Step 10: Configuring /etc/hosts${NC}"
echo ""

# Add host entries if not present
if ! grep -q "es01" /etc/hosts; then
    $SUDO bash -c 'echo "127.0.0.1 es01 infinity mysql minio redis sandbox-executor-manager" >> /etc/hosts'
fi

echo -e "${GREEN}✓ Hosts configured${NC}"
echo ""

# ==================== Summary ====================
echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo -e "==========================================${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Data Directory:  $DATA_DIR"
echo "  MySQL Port:      $MYSQL_PORT"
echo "  Redis Port:      $REDIS_PORT"
echo "  MinIO Port:      $MINIO_PORT (Console: $MINIO_CONSOLE_PORT)"
echo "  Elasticsearch:   $ES_PORT"
echo ""
echo -e "${BLUE}Default Credentials:${NC}"
echo "  MySQL:         root / ${MYSQL_PASSWORD}"
echo "  Redis:         ${REDIS_PASSWORD}"
echo "  MinIO:         ${MINIO_USER} / ${MINIO_PASSWORD}"
echo "  Elasticsearch: elastic / ${ES_PASSWORD}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Start infrastructure: bash start_infrastructure_runpod.sh"
echo "  2. Start RAGFlow:        bash start_ragflow_runpod.sh"
echo ""
echo -e "${YELLOW}Or run the combined startup:${NC}"
echo "  bash start_ragflow_runpod.sh"
echo ""
