#!/bin/bash
#
# RAGFlow Stop Script
# Gracefully stops all RAGFlow services
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow Stop Script"
echo "==========================================${NC}"
echo ""

# Stop backend processes
echo -e "${BLUE}Stopping backend services...${NC}"

if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping ragflow_server...${NC}"
    pkill -SIGTERM -f ragflow_server.py

    # Wait for graceful shutdown
    sleep 2

    # Force kill if still running
    if pgrep -f "ragflow_server.py" >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping ragflow_server...${NC}"
        pkill -9 -f ragflow_server.py
    fi

    echo -e "${GREEN}✓ ragflow_server stopped${NC}"
else
    echo -e "${YELLOW}ragflow_server is not running${NC}"
fi

if pgrep -f "task_executor.py" >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping task_executor...${NC}"
    pkill -SIGTERM -f task_executor.py

    # Wait for graceful shutdown
    sleep 2

    # Force kill if still running
    if pgrep -f "task_executor.py" >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping task_executor...${NC}"
        pkill -9 -f task_executor.py
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
    lsof -ti:9222 | xargs kill -SIGTERM 2>/dev/null

    # Wait for graceful shutdown
    sleep 2

    # Force kill if still running
    if lsof -ti:9222 >/dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping frontend...${NC}"
        lsof -ti:9222 | xargs kill -9 2>/dev/null
    fi

    echo -e "${GREEN}✓ Frontend stopped${NC}"
else
    echo -e "${YELLOW}Frontend is not running on port 9222${NC}"
fi

# Verify all processes are stopped
echo ""
echo -e "${BLUE}Verifying shutdown...${NC}"

if pgrep -f "ragflow_server.py" >/dev/null 2>&1 || pgrep -f "task_executor.py" >/dev/null 2>&1; then
    echo -e "${RED}✗ Some backend processes are still running${NC}"
    echo "PIDs: $(pgrep -f 'ragflow_server.py\|task_executor.py' | tr '\n' ' ')"
    exit 1
fi

if lsof -ti:9222 >/dev/null 2>&1; then
    echo -e "${RED}✗ Frontend is still running on port 9222${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All RAGFlow processes stopped${NC}"
echo ""

# Ask if user wants to stop infrastructure services
echo -e "${YELLOW}Do you want to stop infrastructure services? (MySQL, Redis, MinIO, Elasticsearch)${NC}"
read -p "(y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Stopping infrastructure services...${NC}"

    sudo systemctl stop mysql
    echo -e "${GREEN}✓ MySQL stopped${NC}"

    sudo systemctl stop redis-server
    echo -e "${GREEN}✓ Redis stopped${NC}"

    sudo systemctl stop minio
    echo -e "${GREEN}✓ MinIO stopped${NC}"

    sudo systemctl stop elasticsearch
    echo -e "${GREEN}✓ Elasticsearch stopped${NC}"

    echo ""
    echo -e "${GREEN}All infrastructure services stopped${NC}"
else
    echo ""
    echo -e "${YELLOW}Infrastructure services left running${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "RAGFlow Stopped Successfully!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}To start RAGFlow again, run:${NC}"
echo "  bash start_ragflow.sh"
echo ""
