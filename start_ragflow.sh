#!/bin/bash
#
# RAGFlow Automated Startup Script
# Starts all required services and launches RAGFlow with GPU support
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Startup Script"
echo -e "==========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${GREEN}Script directory: $SCRIPT_DIR"
echo ""
cd "$SCRIPT_DIR"

# Function to check if a service is running
check_service() {
    local service_name=$1
    if sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}✓ $service_name is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not running${NC}"
        return 1
    fi
}

# Function to check if a port is in use
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $service is listening on port $port${NC}"
        return 0
    else
        echo -e "${RED}✗ $service is not listening on port $port${NC}"
        return 1
    fi
}

# Step 1: Check and start infrastructure services
echo -e "${BLUE}Step 1: Checking infrastructure services${NC}"
echo ""

SERVICES_OK=true

# Check MySQL
if ! check_service mysql; then
    echo -e "${YELLOW}Starting MySQL...${NC}"
    sudo systemctl start mysql
    sleep 2
    if ! check_service mysql; then
        echo -e "${RED}Failed to start MySQL${NC}"
        SERVICES_OK=false
    fi
fi

# Check Redis
if ! check_service redis-server; then
    echo -e "${YELLOW}Starting Redis...${NC}"
    sudo systemctl start redis-server
    sleep 2
    if ! check_service redis-server; then
        echo -e "${RED}Failed to start Redis${NC}"
        SERVICES_OK=false
    fi
fi

# Check MinIO
if ! check_service minio; then
    echo -e "${YELLOW}Starting MinIO...${NC}"
    sudo systemctl start minio
    sleep 2
    if ! check_service minio; then
        echo -e "${RED}Failed to start MinIO${NC}"
        SERVICES_OK=false
    fi
fi

# Check Elasticsearch
if ! check_service elasticsearch; then
    echo -e "${YELLOW}Starting Elasticsearch...${NC}"
    sudo systemctl start elasticsearch
    sleep 5  # Elasticsearch takes longer to start
    if ! check_service elasticsearch; then
        echo -e "${RED}Failed to start Elasticsearch${NC}"
        SERVICES_OK=false
    fi
fi

if [ "$SERVICES_OK" = false ]; then
    echo ""
    echo -e "${RED}Some infrastructure services failed to start. Please check the logs:${NC}"
    echo "  sudo journalctl -u mysql -n 50"
    echo "  sudo journalctl -u redis-server -n 50"
    echo "  sudo journalctl -u minio -n 50"
    echo "  sudo journalctl -u elasticsearch -n 50"
    exit 1
fi

echo ""
echo -e "${GREEN}All infrastructure services are running!${NC}"
echo ""

# Step 2: Verify service connectivity
echo -e "${BLUE}Step 2: Verifying service connectivity${NC}"
echo ""

# Test MySQL
if mysql -u root -pinfini_rag_flow -h 127.0.0.1 -P 5455 -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL connection OK (port 5455)${NC}"
else
    echo -e "${RED}✗ MySQL connection failed${NC}"
    exit 1
fi

# Test Redis
if redis-cli -a infini_rag_flow ping >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis connection OK (port 6379)${NC}"
else
    echo -e "${RED}✗ Redis connection failed${NC}"
    exit 1
fi

# Test MinIO
if curl -s http://127.0.0.1:9000/minio/health/live | grep -q "success\|ready" 2>/dev/null || curl -sf http://127.0.0.1:9000/minio/health/live >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MinIO connection OK (port 9000)${NC}"
else
    echo -e "${YELLOW}⚠ MinIO health check inconclusive (may be OK)${NC}"
fi

# Test Elasticsearch
if curl -s -u elastic:infini_rag_flow http://127.0.0.1:1200 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch connection OK (port 1200)${NC}"
else
    echo -e "${RED}✗ Elasticsearch connection failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All services are accessible!${NC}"
echo ""

# Step 3: Check if conda is active and deactivate
echo -e "${BLUE}Step 3: Preparing Python environment${NC}"
echo ""

if [ -n "${CONDA_DEFAULT_ENV:-}" ]; then
    echo -e "${YELLOW}Conda environment detected: $CONDA_DEFAULT_ENV${NC}"
    echo -e "${YELLOW}Deactivating conda to use uv virtual environment...${NC}"
    # Note: conda deactivate doesn't work in scripts, so we'll warn the user
    echo -e "${RED}WARNING: Please run 'conda deactivate' manually before running this script${NC}"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo -e "${RED}Virtual environment not found at $SCRIPT_DIR/.venv${NC}"
    echo "Please run 'uv venv' to create it first"
    exit 1
fi

echo -e "${GREEN}Virtual environment found${NC}"
echo ""

# Step 4: Check for running RAGFlow processes
echo -e "${BLUE}Step 4: Checking for existing RAGFlow processes${NC}"
echo ""

if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}RAGFlow backend is already running${NC}"
    echo "PID(s): $(pgrep -f 'ragflow_server.py' | tr '\n' ' ')"
    echo ""
    read -p "Do you want to stop and restart it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping existing backend...${NC}"
        pkill -f ragflow_server.py
        pkill -f task_executor.py
        sleep 2
    else
        echo -e "${YELLOW}Keeping existing backend running${NC}"
        BACKEND_ALREADY_RUNNING=true
    fi
fi

if pgrep -f "npm.*dev" >/dev/null 2>&1 || lsof -ti:9222 >/dev/null 2>&1; then
    echo -e "${YELLOW}Frontend development server is already running on port 9222${NC}"
    echo ""
    read -p "Do you want to stop and restart it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping existing frontend...${NC}"
        lsof -ti:9222 | xargs kill -9 2>/dev/null || true
        sleep 2
    else
        echo -e "${YELLOW}Keeping existing frontend running${NC}"
        FRONTEND_ALREADY_RUNNING=true
    fi
fi

# Step 5: Start backend
if [ "${BACKEND_ALREADY_RUNNING:-}" != true ]; then
    echo ""
    echo -e "${BLUE}Step 5: Starting RAGFlow backend${NC}"
    echo ""
    echo -e "${YELLOW}Backend will start in the background...${NC}"
    echo -e "${YELLOW}Logs: $SCRIPT_DIR/logs/ragflow_server.log${NC}"
    echo ""

    # Start backend in background using nohup
    cd "$SCRIPT_DIR"
    export PYTHONPATH="$SCRIPT_DIR"
    nohup bash launch_backend_service.sh > /tmp/ragflow_backend_startup.log 2>&1 &
    BACKEND_PID=$!

    echo "Backend starting with PID: $BACKEND_PID"
    echo "Waiting for backend to initialize (30 seconds)..."

    # Wait and check if backend starts successfully
    for i in {1..30}; do
        sleep 1
        if grep -q "Running on http" "$SCRIPT_DIR/logs/ragflow_server.log" 2>/dev/null; then
            echo -e "${GREEN}✓ Backend started successfully!${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}✗ Backend may have failed to start. Check logs:${NC}"
            echo "  tail -f $SCRIPT_DIR/logs/ragflow_server.log"
            echo "  cat /tmp/ragflow_backend_startup.log"
            exit 1
        fi
    done
else
    echo ""
    echo -e "${BLUE}Step 5: Backend already running, skipping...${NC}"
fi

# Step 6: Frontend (manual start required)
echo ""
echo -e "${BLUE}Step 6: Frontend Development Server${NC}"
echo ""

if lsof -Pi :9222 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Frontend is already running on port 9222${NC}"
    FRONTEND_ALREADY_RUNNING=true
else
    echo -e "${YELLOW}⚠ Frontend must be started manually in a separate terminal${NC}"
    echo ""
    echo -e "${BLUE}Why manual start is required:${NC}"
    echo "  The frontend build process requires an interactive terminal for proper"
    echo "  compilation. Background startup causes esbuild deadlocks."
    echo ""
    echo -e "${BLUE}To start the frontend, open a new terminal and run:${NC}"
    echo ""
    echo -e "${GREEN}  cd $SCRIPT_DIR/web${NC}"
    echo -e "${GREEN}  npm run dev${NC}"
    echo ""
    echo -e "${YELLOW}The frontend will be available at: http://localhost:9222${NC}"
    echo -e "${YELLOW}Compilation takes 20-40 seconds on first run${NC}"
    echo ""

    cd "$SCRIPT_DIR/web"
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Installing frontend dependencies first...${NC}"
        npm install
        echo ""
    fi
fi

# Step 7: Verify GPU usage
echo ""
echo -e "${BLUE}Step 7: Verifying GPU usage${NC}"
echo ""

if command -v nvidia-smi &> /dev/null; then
    sleep 2  # Give processes time to initialize GPU
    if nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✓ GPU is being utilized by RAGFlow${NC}"
        nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
    else
        echo -e "${YELLOW}⚠ No GPU processes detected yet (may appear after first use)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ nvidia-smi not found, skipping GPU check${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}=========================================="
echo "RAGFlow Started Successfully!"
echo "==========================================${NC}"
echo ""
echo -e "${GREEN}Application URL:${NC} http://localhost:9222"
echo -e "${GREEN}Backend API:${NC}     http://127.0.0.1:9380"
echo ""
echo -e "${BLUE}Process Information:${NC}"
if [ -n "${BACKEND_PID:-}" ]; then
    echo "  Backend PID: $BACKEND_PID"
fi
if [ "${FRONTEND_ALREADY_RUNNING:-}" = true ]; then
    FRONTEND_PID=$(lsof -ti:9222 2>/dev/null || echo "")
    if [ -n "$FRONTEND_PID" ]; then
        echo "  Frontend PID: $FRONTEND_PID"
    fi
fi
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  Backend:  $SCRIPT_DIR/logs/ragflow_server.log"
echo ""
echo -e "${BLUE}To stop RAGFlow:${NC}"
echo "  Backend:  pkill -f ragflow_server.py && pkill -f task_executor.py"
echo "  Frontend: Press Ctrl+C in the terminal running npm dev (or lsof -ti:9222 | xargs kill)"
echo ""
echo -e "${BLUE}To view backend logs in real-time:${NC}"
echo "  tail -f $SCRIPT_DIR/logs/ragflow_server.log"
echo ""
if [ "${FRONTEND_ALREADY_RUNNING:-}" != true ]; then
    echo -e "${YELLOW}Remember to start the frontend in a separate terminal!${NC}"
    echo -e "${GREEN}  cd $SCRIPT_DIR/web && npm run dev${NC}"
    echo ""
fi
echo -e "${GREEN}Once frontend is running, open your browser to http://localhost:9222${NC}"
echo ""
