#!/bin/bash
#
# RAGFlow RunPod Setup Validation Script
# This script performs comprehensive validation of the RunPod setup
# to ensure all components are properly configured and ready for use.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "RAGFlow RunPod Setup Validation"
echo -e "==========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Validation results tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Array to store detailed results
declare -a RESULTS

# Function to record check result
record_check() {
    local status=$1
    local message=$2
    local details=${3:-""}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            echo -e "${GREEN}✓ PASS${NC}: $message"
            RESULTS+=("PASS: $message")
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo -e "${RED}✗ FAIL${NC}: $message"
            if [ -n "$details" ]; then
                echo -e "  ${RED}Details: $details${NC}"
            fi
            RESULTS+=("FAIL: $message ${details:+- $details}")
            ;;
        "WARN")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo -e "${YELLOW}⚠ WARNING${NC}: $message"
            if [ -n "$details" ]; then
                echo -e "  ${YELLOW}Details: $details${NC}"
            fi
            RESULTS+=("WARN: $message ${details:+- $details}")
            ;;
    esac
}

# ==================== Section 1: Script Files Validation ====================
echo -e "${CYAN}[1/10] Validating Script Files${NC}"
echo ""

# Check if all required scripts exist
scripts=(
    "setup_runpod.sh"
    "setup_and_start_runpod.sh"
    "start_ragflow_runpod.sh"
    "start_infrastructure_runpod.sh"
    "stop_ragflow_runpod.sh"
    "launch_backend_service.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        record_check "PASS" "Script exists: $script"
        # Check if executable
        if [ -x "$SCRIPT_DIR/$script" ]; then
            record_check "PASS" "Script is executable: $script"
        else
            record_check "WARN" "Script is not executable: $script" "Consider running: chmod +x $script"
        fi
    else
        record_check "FAIL" "Script missing: $script"
    fi
done

echo ""

# ==================== Section 2: Documentation Validation ====================
echo -e "${CYAN}[2/10] Validating Documentation${NC}"
echo ""

docs=(
    "README_RUNPOD.md"
    "RUNPOD_QUICK_REFERENCE.md"
    "RUNPOD_SETUP_FIX.md"
    ".env.runpod.example"
)

for doc in "${docs[@]}"; do
    if [ -f "$SCRIPT_DIR/$doc" ]; then
        record_check "PASS" "Documentation exists: $doc"
    else
        record_check "FAIL" "Documentation missing: $doc"
    fi
done

# Check if CLAUDE.md mentions RunPod (case-insensitive) - informational only
if [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
    if grep -qi "runpod" "$SCRIPT_DIR/CLAUDE.md" 2>/dev/null; then
        record_check "PASS" "CLAUDE.md includes RunPod documentation"
    else
        record_check "PASS" "CLAUDE.md exists (RunPod section optional)"
    fi
else
    record_check "WARN" "CLAUDE.md not found"
fi

echo ""

# ==================== Section 3: Configuration Validation ====================
echo -e "${CYAN}[3/10] Validating Configuration Files${NC}"
echo ""

# Check service_conf.yaml
if [ -f "$SCRIPT_DIR/conf/service_conf.yaml" ]; then
    record_check "PASS" "service_conf.yaml exists"
    
    # Check if default credentials match documentation
    if grep -q "password: 'infini_rag_flow'" "$SCRIPT_DIR/conf/service_conf.yaml"; then
        record_check "PASS" "service_conf.yaml uses documented default password"
    else
        record_check "WARN" "service_conf.yaml password differs from documentation"
    fi
    
    # Check port configurations
    if grep -q "port: 5455" "$SCRIPT_DIR/conf/service_conf.yaml"; then
        record_check "PASS" "MySQL port matches documentation (5455)"
    else
        record_check "WARN" "MySQL port differs from documentation"
    fi
    
    if grep -q "host: '127.0.0.1:9000'" "$SCRIPT_DIR/conf/service_conf.yaml"; then
        record_check "PASS" "MinIO host matches documentation"
    else
        record_check "WARN" "MinIO host differs from documentation"
    fi
    
    if grep -q "hosts: 'http://127.0.0.1:1200'" "$SCRIPT_DIR/conf/service_conf.yaml"; then
        record_check "PASS" "Elasticsearch host matches documentation"
    else
        record_check "WARN" "Elasticsearch host differs from documentation"
    fi
    
    if grep -q "host: '127.0.0.1:6379'" "$SCRIPT_DIR/conf/service_conf.yaml"; then
        record_check "PASS" "Redis host matches documentation"
    else
        record_check "WARN" "Redis host differs from documentation"
    fi
else
    record_check "FAIL" "service_conf.yaml missing"
fi

# Check .env.runpod.example
if [ -f "$SCRIPT_DIR/.env.runpod.example" ]; then
    record_check "PASS" ".env.runpod.example exists"
    
    # Validate key configurations
    if grep -q "MYSQL_PORT=5455" "$SCRIPT_DIR/.env.runpod.example"; then
        record_check "PASS" ".env.runpod.example has correct MySQL port"
    else
        record_check "WARN" ".env.runpod.example MySQL port differs"
    fi
else
    record_check "FAIL" ".env.runpod.example missing"
fi

echo ""

# ==================== Section 4: Script Logic Validation ====================
echo -e "${CYAN}[4/10] Validating Script Logic${NC}"
echo ""

# Check if setup_and_start_runpod.sh exports MinIO credentials
if grep -q "export MINIO_ROOT_USER=" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh exports MINIO_ROOT_USER"
else
    record_check "FAIL" "setup_and_start_runpod.sh missing MINIO_ROOT_USER export"
fi

if grep -q "export MINIO_ROOT_PASSWORD=" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh exports MINIO_ROOT_PASSWORD"
else
    record_check "FAIL" "setup_and_start_runpod.sh missing MINIO_ROOT_PASSWORD export"
fi

# Check if start_infrastructure_runpod.sh sets MinIO credentials
if grep -q "MINIO_ROOT_USER=" "$SCRIPT_DIR/start_infrastructure_runpod.sh"; then
    record_check "PASS" "start_infrastructure_runpod.sh sets MINIO_ROOT_USER"
else
    record_check "FAIL" "start_infrastructure_runpod.sh missing MINIO_ROOT_USER"
fi

# Check for wait_for_port function in critical scripts
if grep -q "wait_for_port()" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh has wait_for_port() function"
else
    record_check "WARN" "setup_and_start_runpod.sh missing wait_for_port() function"
fi

# Check for error handling (set -e)
if grep -q "set -e" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh has error handling (set -e)"
else
    record_check "WARN" "setup_and_start_runpod.sh missing set -e"
fi

# Check for idempotency (port checking before starting services)
if grep -q "check_port" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh has port checking for idempotency"
else
    record_check "WARN" "setup_and_start_runpod.sh may not be idempotent"
fi

# Check for MySQL root workaround
if grep -q "user=root" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh has MySQL root workaround for containers"
else
    record_check "WARN" "setup_and_start_runpod.sh may have MySQL permission issues in containers"
fi

echo ""

# ==================== Section 5: Logging Configuration ====================
echo -e "${CYAN}[5/10] Validating Logging Configuration${NC}"
echo ""

# Check if scripts create log directories
if grep -q "LOGS_DIR=" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh defines LOGS_DIR"
else
    record_check "FAIL" "setup_and_start_runpod.sh missing LOGS_DIR definition"
fi

# Check if scripts redirect output to logs
if grep -q ">> .*\.log" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh redirects output to logs"
else
    record_check "WARN" "setup_and_start_runpod.sh may not log service output"
fi

# Check if documentation mentions log locations
if grep -q "/workspace/ragflow-data/logs/" "$SCRIPT_DIR/README_RUNPOD.md"; then
    record_check "PASS" "README_RUNPOD.md documents log locations"
else
    record_check "WARN" "README_RUNPOD.md missing log location documentation"
fi

echo ""

# ==================== Section 6: Port Configuration ====================
echo -e "${CYAN}[6/10] Validating Port Configuration${NC}"
echo ""

# Expected ports
expected_ports=(
    "5455:MySQL"
    "6379:Redis"
    "9000:MinIO API"
    "9001:MinIO Console"
    "1200:Elasticsearch"
    "9380:Backend API"
    "9222:Frontend"
)

for port_info in "${expected_ports[@]}"; do
    port="${port_info%%:*}"
    service="${port_info#*:}"
    
    # Check if port is documented in README_RUNPOD.md
    if grep -q "$port" "$SCRIPT_DIR/README_RUNPOD.md"; then
        record_check "PASS" "Port $port ($service) is documented"
    else
        record_check "WARN" "Port $port ($service) not found in documentation"
    fi
done

echo ""

# ==================== Section 7: Security Configuration ====================
echo -e "${CYAN}[7/10] Validating Security Configuration${NC}"
echo ""

# Check if default passwords are documented
if grep -q "infini_rag_flow" "$SCRIPT_DIR/README_RUNPOD.md"; then
    record_check "PASS" "Default passwords are documented"
else
    record_check "FAIL" "Default passwords not documented"
fi

# Check if security warning exists
if grep -q -i "security\|production" "$SCRIPT_DIR/README_RUNPOD.md"; then
    record_check "PASS" "Security considerations are mentioned"
else
    record_check "WARN" "No security warnings for production use"
fi

# Check if .env.runpod.example includes password change instructions
if grep -qi "security.*password\|change.*password\|production.*password" "$SCRIPT_DIR/.env.runpod.example" 2>/dev/null; then
    record_check "PASS" ".env.runpod.example includes security guidance"
else
    record_check "WARN" ".env.runpod.example missing security guidance"
fi

echo ""

# ==================== Section 8: Data Persistence ====================
echo -e "${CYAN}[8/10] Validating Data Persistence Configuration${NC}"
echo ""

# Check if data directory is configurable
if grep -q "DATA_DIR=" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "DATA_DIR is configurable"
else
    record_check "WARN" "DATA_DIR may not be configurable"
fi

# Check if persistent volume path is used
if grep -q "RUNPOD_VOLUME_PATH" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "Scripts use RUNPOD_VOLUME_PATH for persistence"
else
    record_check "WARN" "Scripts may not use RunPod volume path"
fi

# Check if persistence is documented
if grep -q -i "persist\|volume" "$SCRIPT_DIR/README_RUNPOD.md"; then
    record_check "PASS" "Data persistence is documented"
else
    record_check "WARN" "Data persistence not documented"
fi

echo ""

# ==================== Section 9: GPU Configuration ====================
echo -e "${CYAN}[9/10] Validating GPU Configuration${NC}"
echo ""

# Check if scripts verify GPU availability
if grep -q "nvidia-smi\|cuda" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "setup_and_start_runpod.sh checks GPU availability"
else
    record_check "WARN" "GPU verification not found in setup script"
fi

# Check if PyTorch CUDA is tested
if grep -q "torch.cuda.is_available" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "Scripts test PyTorch CUDA availability"
else
    record_check "WARN" "PyTorch CUDA verification not found"
fi

# Check if GPU requirements are documented
if grep -q -i "gpu\|cuda" "$SCRIPT_DIR/README_RUNPOD.md"; then
    record_check "PASS" "GPU requirements are documented"
else
    record_check "WARN" "GPU requirements not documented"
fi

echo ""

# ==================== Section 10: Dependency Management ====================
echo -e "${CYAN}[10/10] Validating Dependency Management${NC}"
echo ""

# Check if Python dependencies are managed
if [ -f "$SCRIPT_DIR/pyproject.toml" ]; then
    record_check "PASS" "pyproject.toml exists for Python dependencies"
else
    record_check "FAIL" "pyproject.toml missing"
fi

# Check if uv is used for Python package management
if grep -q "uv sync\|uv venv" "$SCRIPT_DIR/setup_and_start_runpod.sh"; then
    record_check "PASS" "Scripts use uv for Python package management"
else
    record_check "WARN" "Scripts may not use uv for package management"
fi

# Check if frontend dependencies are managed
if [ -f "$SCRIPT_DIR/web/package.json" ]; then
    record_check "PASS" "web/package.json exists for frontend dependencies"
else
    record_check "FAIL" "web/package.json missing"
fi

# Check if download_deps.py exists
if [ -f "$SCRIPT_DIR/download_deps.py" ]; then
    record_check "PASS" "download_deps.py exists for additional dependencies"
else
    record_check "WARN" "download_deps.py not found"
fi

# Check if system dependencies are documented
if grep -q "apt-get install\|mysql-server\|redis-server\|elasticsearch" "$SCRIPT_DIR/setup_runpod.sh" 2>/dev/null; then
    record_check "PASS" "System dependencies are installed by setup script"
else
    record_check "WARN" "System dependencies installation not verified"
fi

echo ""

# ==================== Summary ====================
echo -e "${BLUE}=========================================="
echo "Validation Summary"
echo -e "==========================================${NC}"
echo ""

echo -e "${CYAN}Total Checks:${NC} $TOTAL_CHECKS"
echo -e "${GREEN}Passed:${NC}       $PASSED_CHECKS"
echo -e "${YELLOW}Warnings:${NC}     $WARNING_CHECKS"
echo -e "${RED}Failed:${NC}       $FAILED_CHECKS"
echo ""

# Calculate pass percentage (avoid division by zero)
if [ $TOTAL_CHECKS -gt 0 ]; then
    PASS_PERCENT=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    PASS_PERCENT=0
    echo -e "${RED}ERROR: No validation checks were executed!${NC}"
fi
echo -e "${CYAN}Pass Rate:${NC}    $PASS_PERCENT%"
echo ""

# Overall assessment
if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
        echo -e "${GREEN}✓ EXCELLENT: RunPod setup is fully configured and ready for use!${NC}"
        echo -e "${GREEN}All critical checks passed with no warnings.${NC}"
    else
        echo -e "${GREEN}✓ GOOD: RunPod setup is ready for use with minor recommendations.${NC}"
        echo -e "${YELLOW}Review the warnings above for potential improvements.${NC}"
    fi
else
    echo -e "${RED}✗ ISSUES FOUND: RunPod setup has critical issues that need attention.${NC}"
    echo -e "${RED}Review the failed checks above and fix the issues before deployment.${NC}"
fi

echo ""

# Recommendations
if [ $WARNING_CHECKS -gt 0 ] || [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${CYAN}Recommendations:${NC}"
    echo ""
    
    # Collect failed and warning results in separate passes for clarity
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${RED}Critical Issues to Fix:${NC}"
        for result in "${RESULTS[@]}"; do
            if [[ $result == FAIL:* ]]; then
                echo "  - ${result#FAIL: }"
            fi
        done
        echo ""
    fi
    
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}Suggested Improvements:${NC}"
        for result in "${RESULTS[@]}"; do
            if [[ $result == WARN:* ]]; then
                echo "  - ${result#WARN: }"
            fi
        done
        echo ""
    fi
fi

echo -e "${BLUE}Validation Complete!${NC}"
echo ""

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
    exit 1
else
    exit 0
fi
