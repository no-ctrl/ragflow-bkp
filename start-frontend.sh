#!/bin/bash

echo "Starting RAGFlow Frontend..."

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Navigate to web directory
cd web

# Use Node.js 20
nvm use 20

echo "Starting development server on port 3000..."
npm run dev