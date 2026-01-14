#!/usr/bin/env bash
#
# Master script for RunPod: Clones, sets up, and starts the RAGFlow application.
# This script is intended to be the main entry point for a RunPod template.
# It ensures a clean installation and starts all necessary services.
#

set -e

# --- Configuration ---
# The directory where the repository will be cloned
# Use local storage (/root) for better performance than network volume (/workspace)
WORKDIR="/root"
# The URL of the repository to clone
REPO_URL="https://github.com/infiniflow/ragflow.git"
# The name of the repository directory
REPO_NAME="ragflow"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================="
echo "RAGFlow Automated Clone, Setup & Start for RunPod"
echo "================================================="

# --- Step 1: Clone the Repository ---
echo ""
echo "--> Preparing workspace and cloning repository..."
echo ""

# Navigate to the working directory
cd "${WORKDIR}"

# Remove any existing repository directory to ensure a clean clone
if [ -d "${REPO_NAME}" ]; then
    echo "Removing existing repository directory: ${REPO_NAME}"
    rm -rf "${REPO_NAME}"
fi

# Clone the repository
echo "Cloning from ${REPO_URL}..."
git clone "${REPO_URL}"

# Enter the repository directory
cd "${REPO_NAME}"
echo "Successfully cloned and entered the repository."

# Copy setup scripts from the source directory to the cloned repository
# This ensures that any local modifications to the scripts are preserved and used
echo "Copying local scripts to repository..."
cp "${SCRIPT_DIR}"/*.sh .
cp "${SCRIPT_DIR}"/download_deps.py . 2>/dev/null || true

# --- Step 2: Run Setup Script ---
echo ""
echo "--> Executing setup script (setup_runpod.sh)..."
echo ""
if [ -f "setup_runpod.sh" ]; then
    chmod +x setup_runpod.sh
    bash setup_runpod.sh
else
    echo "Error: setup_runpod.sh not found!"
    exit 1
fi

# --- Step 3: Start RAGFlow Application ---
echo ""
echo "--> Starting RAGFlow application (start_ragflow_runpod.sh)..."
echo ""
if [ -f "start_ragflow_runpod.sh" ]; then
    chmod +x start_ragflow_runpod.sh
    bash start_ragflow_runpod.sh
else
    echo "Error: start_ragflow_runpod.sh not found!"
    exit 1
fi

echo ""
echo "================================================="
echo "RAGFlow startup process is complete."
echo "The application services are now running."
echo "================================================="
echo ""
