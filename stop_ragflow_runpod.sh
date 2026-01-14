#!/bin/bash
#
# RAGFlow Stop Script for RunPod
# Gracefully stops all RAGFlow services
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Stop Script for RunPod"
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
fi

DATA_DIR="${DATA_DIR:-${RUNPOD_VOLUME_PATH:-/workspace}/ragflow-data}"
PIDS_DIR="$DATA_DIR/pids"

# Function to stop a service by PID file
stop_service_by_pid() {
    local service_name=$1
    local pid_file="$PIDS_DIR/${2:-$service_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            echo -e "${GREEN}✓ $service_name stopped${NC}"
        fi
        rm -f "$pid_file"
    fi
}

# Stop backend processes
echo -e "${BLUE}Stopping backend services...${NC}"

if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping ragflow_server...${NC}"
    pkill -SIGTERM -f ragflow_server.py || true
    sleep 2
    
    if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping ragflow_server...${NC}"
        pkill -9 -f ragflow_server.py || true
    fi
    echo -e "${GREEN}✓ ragflow_server stopped${NC}"
else
    echo -e "${YELLOW}ragflow_server is not running${NC}"
fi

if pgrep -f "task_executor.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping task_executor...${NC}"
    pkill -SIGTERM -f task_executor.py || true
    sleep 2
    
    if pgrep -f "task_executor.py" >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping task_executor...${NC}"
        pkill -9 -f task_executor.py || true
    fi
    echo -e "${GREEN}✓ task_executor stopped${NC}"
else
    echo -e "${YELLOW}task_executor is not running${NC}"
fi

# Stop frontend
echo ""
echo -e "${BLUE}Stopping frontend...${NC}"

if lsof -ti:9222 >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping frontend on port 9222...${NC}"
    lsof -ti:9222 | xargs kill -SIGTERM 2>/dev/null || true
    sleep 2
    
    if lsof -ti:9222 >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping frontend...${NC}"
        lsof -ti:9222 | xargs kill -9 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ Frontend stopped${NC}"
else
    echo -e "${YELLOW}Frontend is not running on port 9222${NC}"
fi

# Verify all RAGFlow processes are stopped
echo ""
echo -e "${BLUE}Verifying RAGFlow shutdown...${NC}"

if pgrep -f "ragflow_server.py" >/dev/null 2>&1 || pgrep -f "task_executor.py" >/dev/null 2>&1; then
    echo -e "${RED}✗ Some backend processes are still running${NC}"
    echo "PIDs: $(pgrep -f 'ragflow_server.py\|task_executor.py' | tr '\n' ' ')"
else
    echo -e "${GREEN}✓ All RAGFlow processes stopped${NC}"
fi

# Clean up PID files
rm -f "$PIDS_DIR/ragflow_backend.pid" "$PIDS_DIR/ragflow_frontend.pid" 2>/dev/null || true

echo ""

# Ask about infrastructure services (non-interactive by default in RunPod)
STOP_INFRA="${1:-}"

if [ "$STOP_INFRA" = "--stop-infra" ] || [ "$STOP_INFRA" = "-s" ]; then
    echo -e "${BLUE}Stopping infrastructure services...${NC}"
    
    # Stop all infrastructure services using helper function
    stop_service_by_pid "MySQL" "mysql"
    stop_service_by_pid "Redis" "redis"
    stop_service_by_pid "MinIO" "minio"
    stop_service_by_pid "Elasticsearch" "elasticsearch"
    
    echo ""
    echo -e "${GREEN}All infrastructure services stopped${NC}"
else
    echo -e "${YELLOW}Infrastructure services left running.${NC}"
    echo "To stop infrastructure, run: bash stop_ragflow_runpod.sh --stop-infra"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "RAGFlow Stopped Successfully!"
echo -e "==========================================${NC}"
echo ""
echo -e "${BLUE}To start RAGFlow again, run:${NC}"
echo "  bash start_ragflow_runpod.sh"
echo ""
