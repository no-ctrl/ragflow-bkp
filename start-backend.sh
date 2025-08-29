#!/bin/bash

echo "Starting RAGFlow Backend..."

# Activate virtual environment
source .venv/bin/activate

# Set Python path
export PYTHONPATH=$(pwd)

# Set HuggingFace mirror if needed
export HF_ENDPOINT=https://hf-mirror.com

# Start the backend server
echo "Starting API server on port 9380..."
python api/ragflow_server.py