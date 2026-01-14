#!/bin/bash
#
# RAGFlow Automated Startup Script for RunPod
# Starts all required services and launches RAGFlow with GPU support
# Designed for runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04 image
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Startup Script for RunPod"
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
    echo -e "${YELLOW}No .env file found. Using defaults.${NC}"
fi

# Configuration defaults
DATA_DIR="${DATA_DIR:-${RUNPOD_VOLUME_PATH:-/workspace}/ragflow-data}"
LOGS_DIR="$DATA_DIR/logs"
PIDS_DIR="$DATA_DIR/pids"

# Create directories
mkdir -p "$LOGS_DIR" "$PIDS_DIR" "$SCRIPT_DIR/logs"

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ==================== Step 1: Start Infrastructure ====================
echo -e "${BLUE}Step 1: Starting infrastructure services${NC}"
echo ""

# Check if infrastructure is running, if not start it
MYSQL_PORT=${MYSQL_PORT:-5455}
REDIS_PORT=${REDIS_PORT:-6379}
MINIO_PORT=${MINIO_PORT:-9000}
ES_PORT=${ES_PORT:-1200}

INFRA_RUNNING=true
check_port $MYSQL_PORT || INFRA_RUNNING=false
check_port $REDIS_PORT || INFRA_RUNNING=false
check_port $MINIO_PORT || INFRA_RUNNING=false
check_port $ES_PORT || INFRA_RUNNING=false

if [ "$INFRA_RUNNING" = false ]; then
    echo "Starting infrastructure services..."
    bash "$SCRIPT_DIR/start_infrastructure_runpod.sh"
else
    echo -e "${GREEN}✓ Infrastructure services already running${NC}"
fi

echo ""

# ==================== Step 2: Verify Service Connectivity ====================
echo -e "${BLUE}Step 2: Verifying service connectivity${NC}"
echo ""

MYSQL_PASSWORD=${MYSQL_PASSWORD:-"infini_rag_flow"}
REDIS_PASSWORD=${REDIS_PASSWORD:-"infini_rag_flow"}
ES_PASSWORD=${ES_PASSWORD:-"infini_rag_flow"}

# Test MySQL
if mysql -u root -p"${MYSQL_PASSWORD}" -h 127.0.0.1 -P $MYSQL_PORT -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL connection OK (port $MYSQL_PORT)${NC}"
else
    echo -e "${RED}✗ MySQL connection failed${NC}"
    exit 1
fi

# Test Redis
if redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✓ Redis connection OK (port $REDIS_PORT)${NC}"
else
    echo -e "${RED}✗ Redis connection failed${NC}"
    exit 1
fi

# Test MinIO
if curl -sf "http://127.0.0.1:$MINIO_PORT/minio/health/live" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MinIO connection OK (port $MINIO_PORT)${NC}"
else
    echo -e "${YELLOW}⚠ MinIO health check inconclusive (may be OK)${NC}"
fi

# Test Elasticsearch
if curl -sf -u elastic:"$ES_PASSWORD" "http://127.0.0.1:$ES_PORT" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch connection OK (port $ES_PORT)${NC}"
else
    echo -e "${RED}✗ Elasticsearch connection failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All services are accessible!${NC}"
echo ""

# ==================== Step 3: Prepare Python Environment ====================
echo -e "${BLUE}Step 3: Preparing Python environment${NC}"
echo ""

VENV_DIR="/opt/ragflow_venv"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}Virtual environment not found at $VENV_DIR${NC}"
    echo "Please run setup_runpod.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Virtual environment found${NC}"
echo ""

# ==================== Step 4: Check for Running RAGFlow Processes ====================
echo -e "${BLUE}Step 4: Checking for existing RAGFlow processes${NC}"
echo ""

BACKEND_ALREADY_RUNNING=false
FRONTEND_ALREADY_RUNNING=false

if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}RAGFlow backend is already running${NC}"
    echo "PID(s): $(pgrep -f 'ragflow_server.py' | tr '\n' ' ')"
    BACKEND_ALREADY_RUNNING=true
fi

if check_port 9222; then
    echo -e "${YELLOW}Frontend is already running on port 9222${NC}"
    FRONTEND_ALREADY_RUNNING=true
fi

# ==================== Step 5: Start Backend ====================
if [ "$BACKEND_ALREADY_RUNNING" = false ]; then
    echo ""
    echo -e "${BLUE}Step 5: Starting RAGFlow backend${NC}"
    echo ""
    
    # Activate virtual environment and start backend
    cd "$SCRIPT_DIR"
    
    # Create app logs directory
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Start backend in background
    (
        source "$VENV_DIR/bin/activate"
        export PYTHONPATH="$SCRIPT_DIR"
        bash launch_backend_service.sh >> "$SCRIPT_DIR/logs/ragflow_server.log" 2>&1
    ) &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$PIDS_DIR/ragflow_backend.pid"
    
    echo "Backend starting with PID: $BACKEND_PID"
    echo "Waiting for backend to initialize..."
    
    # Wait for backend to start
    for i in {1..60}; do
        sleep 1
        if check_port 9380; then
            echo -e "${GREEN}✓ Backend started successfully on port 9380!${NC}"
            break
        fi
        if [ $i -eq 60 ]; then
            echo -e "${RED}✗ Backend may have failed to start. Check logs:${NC}"
            echo "  tail -f $SCRIPT_DIR/logs/ragflow_server.log"
            exit 1
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "Still waiting... ($i seconds)"
        fi
    done
else
    echo ""
    echo -e "${BLUE}Step 5: Backend already running, skipping...${NC}"
fi

# ==================== Step 6: Start Frontend ====================
if [ "$FRONTEND_ALREADY_RUNNING" = false ]; then
    echo ""
    echo -e "${BLUE}Step 6: Starting frontend${NC}"
    echo ""
    
    cd "$SCRIPT_DIR/web"
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo "Installing frontend dependencies..."
        npm install
    fi
    
    # Start frontend in background
    (
        npm run dev >> "$LOGS_DIR/frontend.log" 2>&1
    ) &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$PIDS_DIR/ragflow_frontend.pid"
    
    echo "Frontend starting with PID: $FRONTEND_PID"
    echo "Waiting for frontend to initialize..."
    
    # Wait for frontend to start
    for i in {1..120}; do
        sleep 1
        if check_port 9222; then
            echo -e "${GREEN}✓ Frontend started successfully on port 9222!${NC}"
            break
        fi
        if [ $i -eq 120 ]; then
            echo -e "${YELLOW}⚠ Frontend may still be compiling. Check logs:${NC}"
            echo "  tail -f $LOGS_DIR/frontend.log"
        fi
        if [ $((i % 20)) -eq 0 ]; then
            echo "Still waiting for frontend... ($i seconds)"
        fi
    done
    
    cd "$SCRIPT_DIR"
else
    echo ""
    echo -e "${BLUE}Step 6: Frontend already running, skipping...${NC}"
fi

# ==================== Step 7: Verify GPU Usage ====================
echo ""
echo -e "${BLUE}Step 7: Checking GPU availability${NC}"
echo ""

if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}GPU Information:${NC}"
    nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free,utilization.gpu --format=csv
    echo ""
    
    # Check CUDA availability in Python (using subshell to avoid affecting main script)
    CUDA_AVAILABLE=$(source "$VENV_DIR/bin/activate" && python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "false")
    if [ "$CUDA_AVAILABLE" = "True" ]; then
        echo -e "${GREEN}✓ PyTorch CUDA is available${NC}"
        CUDA_DEVICE=$(source "$VENV_DIR/bin/activate" && python -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null || echo "Unknown")
        echo -e "  Device: $CUDA_DEVICE"
    else
        echo -e "${YELLOW}⚠ PyTorch CUDA is not available${NC}"
    fi
else
    echo -e "${YELLOW}⚠ nvidia-smi not found, skipping GPU check${NC}"
fi

# ==================== Final Summary ====================
echo ""
echo -e "${GREEN}=========================================="
echo "RAGFlow Started Successfully!"
echo -e "==========================================${NC}"
echo ""
echo -e "${GREEN}Application URLs:${NC}"
echo "  Frontend:    http://localhost:9222"
echo "  Backend API: http://127.0.0.1:9380"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo "  MinIO Console: http://127.0.0.1:${MINIO_CONSOLE_PORT:-9001}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  Backend:  $SCRIPT_DIR/logs/ragflow_server.log"
echo "  Frontend: $LOGS_DIR/frontend.log"
echo "  Services: $LOGS_DIR/"
echo ""
echo -e "${BLUE}To stop RAGFlow:${NC}"
echo "  bash stop_ragflow_runpod.sh"
echo ""
echo -e "${BLUE}To view backend logs:${NC}"
echo "  tail -f $SCRIPT_DIR/logs/ragflow_server.log"
echo ""
echo -e "${GREEN}Open your browser to: http://localhost:9222${NC}"
echo ""

# If running in RunPod, show the pod URL
if [ -n "${RUNPOD_POD_ID:-}" ]; then
    echo -e "${YELLOW}Note: In RunPod, access the application via the exposed ports in your pod settings.${NC}"
    echo ""
fi
