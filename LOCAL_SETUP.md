# RAGFlow Local Setup Guide

This guide explains how to run RAGFlow locally without Docker.

## Prerequisites Installed

✅ Python 3.12.3
✅ Node.js 20.19.4 (via nvm)
✅ uv (Python package manager)
✅ Elasticsearch 8.11.3
✅ MySQL 8.0.39
✅ Redis 7.2.4
✅ MinIO (S3-compatible storage)

## Directory Structure

- Main project: `/home/arefmikati/projects/ragflow/`
- Services: `~/ragflow-services/`
  - Elasticsearch: `~/ragflow-services/elasticsearch-8.11.3/`
  - MySQL: `~/ragflow-services/mysql-8.0.39-linux-glibc2.28-x86_64/`
  - Redis: `~/ragflow-services/redis-7.2.4/`
  - MinIO: `~/ragflow-services/minio`

## Important Configuration

### 1. Add to /etc/hosts (REQUIRED)
```bash
sudo nano /etc/hosts
# Add this line:
127.0.0.1       es01 infinity mysql minio redis
```

### 2. Service Credentials
All services use the same password: `infini_rag_flow`

- **Elasticsearch**: elastic / infini_rag_flow (port 1200)
- **MySQL**: root / infini_rag_flow (port 5455, database: rag_flow)
- **Redis**: infini_rag_flow (port 6379)
- **MinIO**: rag_flow / infini_rag_flow (API: 9000, Console: 9001)

## Starting RAGFlow

### Step 1: Start All Services
```bash
./start-all-services.sh
```
This will start Elasticsearch, MySQL, Redis, and MinIO.

### Step 2: Start Backend (in a new terminal)
```bash
./start-backend.sh
```
The backend API will be available at http://localhost:9380

### Step 3: Start Frontend (in a new terminal)
```bash
./start-frontend.sh
```
The frontend will be available at http://localhost:3000

## Verifying Services

### Test Elasticsearch
```bash
curl -u elastic:infini_rag_flow http://localhost:1200
```

### Test MySQL
```bash
~/ragflow-services/mysql-8.0.39-linux-glibc2.28-x86_64/bin/mysql \
  --socket=/tmp/mysql_ragflow.sock -u root -p'infini_rag_flow' \
  -e 'SHOW DATABASES;'
```

### Test Redis
```bash
~/ragflow-services/redis-7.2.4/src/redis-cli -a 'infini_rag_flow' ping
```

### Access MinIO Console
Open browser: http://localhost:9001
Login: rag_flow / infini_rag_flow

## Stopping Services

### Stop Backend/Frontend
Press Ctrl+C in their respective terminals

### Stop Individual Services
```bash
# Stop Elasticsearch
pkill -f elasticsearch

# Stop MySQL
~/ragflow-services/mysql-8.0.39-linux-glibc2.28-x86_64/bin/mysqladmin \
  --socket=/tmp/mysql_ragflow.sock -u root -p'infini_rag_flow' shutdown

# Stop Redis
~/ragflow-services/redis-7.2.4/src/redis-cli -a 'infini_rag_flow' shutdown

# Stop MinIO
pkill -f minio
```

## Troubleshooting

### Python Dependencies Issues
Two packages were temporarily disabled due to missing development headers:
- `pyicu` - Requires python3-dev headers
- `datrie` - Requires python3-dev headers

To fix (requires sudo):
```bash
sudo apt-get install python3.12-dev libicu-dev
# Then uncomment the packages in pyproject.toml and run:
uv sync --python 3.12
```

### Frontend Installation
If npm install takes too long, you can try:
```bash
cd web
npm install --registry https://registry.npmmirror.com
```

### Service Connection Issues
1. Ensure all services are running
2. Check that /etc/hosts has the required line
3. Verify ports are not in use: `netstat -tuln | grep -E '1200|5455|6379|9000|9001'`

## Default Login
After starting all services, you can access RAGFlow at http://localhost:3000
Default credentials will be created on first run.

## Notes
- All service data is stored in `~/ragflow-services/`
- Python dependencies are cached by uv
- The virtual environment is in `.venv/`
- Service configurations are in `conf/service_conf.yaml`