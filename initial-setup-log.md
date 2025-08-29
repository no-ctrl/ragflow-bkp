# RAGFlow Initial Setup Log

## Session Overview
Date: 2025-08-28
Objective: Set up RAGFlow locally without Docker for development and customization

## Initial System State
- Python 3.13.2 installed (incompatible - needed 3.10-3.12)
- Python 3.12.3 available at `/usr/bin/python3.12`
- No Node.js installed
- No Docker installed (user preference: local installation)
- Working directory: `/home/arefmikati/projects/ragflow/`

## Step-by-Step Setup Process

### 1. Python Environment Setup

#### 1.1 Verified Python Compatibility
- RAGFlow requires Python 3.10-3.12 (found in `pyproject.toml`: `requires-python = ">=3.10,<3.13"`)
- Confirmed Python 3.12.3 was available: `/usr/bin/python3.12`

#### 1.2 Installed Python Tools
```bash
# Installed uv (fast Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
# Added to PATH: export PATH="$HOME/.local/bin:$PATH"

# Installed pre-commit via uv
uv tool install pre-commit
```

### 2. Node.js Installation

#### 2.1 Installed nvm (Node Version Manager)
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
```

#### 2.2 Installed Node.js 20.19.4
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20
# Result: Node.js v20.19.4, npm 10.9.2
```

### 3. Database and Service Installation

#### 3.1 Elasticsearch 8.11.3
```bash
# Created services directory
mkdir -p ~/ragflow-services && cd ~/ragflow-services

# Downloaded Elasticsearch
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.11.3-linux-x86_64.tar.gz
tar -xzf elasticsearch-8.11.3-linux-x86_64.tar.gz

# Configured elasticsearch.yml:
# - cluster.name: ragflow-cluster
# - node.name: es01
# - network.host: 127.0.0.1
# - http.port: 1200
# - discovery.type: single-node
# - xpack.security.enabled: true
# - xpack.security.http.ssl.enabled: false

# Created start script: ~/ragflow-services/start-elasticsearch.sh
```

#### 3.2 MySQL 8.0.39
```bash
# Downloaded MySQL portable version
cd ~/ragflow-services
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.39-linux-glibc2.28-x86_64.tar.xz
tar -xf mysql-8.0.39-linux-glibc2.28-x86_64.tar.xz

# Created start script: ~/ragflow-services/start-mysql.sh
# Configured to run on port 5455
# Database: rag_flow
# Password: infini_rag_flow
```

#### 3.3 Redis 7.2.4
```bash
# Downloaded and compiled Redis
cd ~/ragflow-services
wget https://download.redis.io/releases/redis-7.2.4.tar.gz
tar -xzf redis-7.2.4.tar.gz
cd redis-7.2.4 && make -j4

# Created start script: ~/ragflow-services/start-redis.sh
# Configured with password: infini_rag_flow
# Port: 6379
```

#### 3.4 MinIO (S3-compatible storage)
```bash
# Downloaded MinIO binary
cd ~/ragflow-services
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio

# Created start script: ~/ragflow-services/start-minio.sh
# API Port: 9000
# Console Port: 9001
# Credentials: rag_flow / infini_rag_flow
```

### 4. Python Dependencies Installation

#### 4.1 Dependency Issues Encountered
Two packages required Python development headers (python3-dev):
- `pyicu>=2.13.1,<3.0.0` - Required for internationalization
- `datrie==0.8.2` - Required for trie data structure

#### 4.2 Temporary Solution
Commented out problematic dependencies in `pyproject.toml`:
```python
# "pyicu>=2.13.1,<3.0.0",  # Temporarily disabled - needs python3-dev
# "datrie==0.8.2",  # Temporarily disabled - needs python3-dev
```

#### 4.3 Installed Dependencies
```bash
export PATH="$HOME/.local/bin:$PATH"
uv sync --python 3.12
# Successfully installed 410+ packages
```

### 5. Service Configuration

#### 5.1 Created Configuration Directory
```bash
mkdir -p conf
cp docker/service_conf.yaml.template conf/service_conf.yaml
```

#### 5.2 Updated service_conf.yaml
Modified all service endpoints to use localhost:
- MySQL: host: '127.0.0.1', port: 5455
- MinIO: host: '127.0.0.1:9000'
- Elasticsearch: hosts: 'http://127.0.0.1:1200'
- Redis: host: '127.0.0.1:6379'

All services configured with password: `infini_rag_flow`

### 6. Frontend Setup

#### 6.1 Checked Frontend Configuration
- Verified `web/.umirc.ts` already configured with proxy to localhost:9380
- Frontend configured to run on port 3000

#### 6.2 Installed Frontend Dependencies
```bash
cd web
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install
```

### 7. Created Startup Scripts

#### 7.1 Master Service Startup Script
`start-all-services.sh` - Starts all backend services (Elasticsearch, MySQL, Redis, MinIO)

#### 7.2 Backend Startup Script
`start-backend.sh` - Activates Python venv and starts Flask API server on port 9380

#### 7.3 Frontend Startup Script
`start-frontend.sh` - Uses nvm to load Node.js and runs React dev server on port 3000

### 8. Documentation Created

#### 8.1 LOCAL_SETUP.md
Comprehensive guide with:
- Prerequisites and directory structure
- Service credentials and ports
- Step-by-step startup instructions
- Troubleshooting tips

#### 8.2 Required Manual Configuration
Need to add to `/etc/hosts`:
```
127.0.0.1       es01 infinity mysql minio redis
```

## Final Configuration Summary

### Service Ports
- Elasticsearch: 1200
- MySQL: 5455
- Redis: 6379
- MinIO API: 9000
- MinIO Console: 9001
- Backend API: 9380
- Frontend: 3000

### All Service Credentials
- Username: `elastic` (ES) / `root` (MySQL) / `rag_flow` (MinIO)
- Password: `infini_rag_flow` (all services)

### Directory Structure
```
/home/arefmikati/projects/ragflow/        # Main project
├── .venv/                                # Python virtual environment
├── conf/service_conf.yaml                # Service configuration
├── start-all-services.sh                 # Start all backend services
├── start-backend.sh                      # Start RAGFlow backend
├── start-frontend.sh                     # Start RAGFlow frontend
├── LOCAL_SETUP.md                        # Setup documentation
└── web/                                   # Frontend code

~/ragflow-services/                       # Service installations
├── elasticsearch-8.11.3/                 # Elasticsearch
├── mysql-8.0.39-linux-glibc2.28-x86_64/ # MySQL
├── redis-7.2.4/                         # Redis
├── minio                                 # MinIO binary
├── mysql-data/                          # MySQL data directory
├── minio-data/                          # MinIO data directory
├── start-elasticsearch.sh               # ES startup script
├── start-mysql.sh                       # MySQL startup script
├── start-redis.sh                       # Redis startup script
└── start-minio.sh                       # MinIO startup script
```

## Known Issues and Solutions

### Python Development Headers
To properly install `pyicu` and `datrie`:
```bash
# Install development headers (requires sudo)
sudo apt-get install python3.12-dev libicu-dev

# Uncomment packages in pyproject.toml
# Then reinstall:
uv sync --python 3.12
```

### Frontend Installation Speed
If npm install is slow, use Chinese mirror:
```bash
npm install --registry https://registry.npmmirror.com
```

## Startup Sequence

1. Add hosts entry (one-time setup)
2. Run `./start-all-services.sh` (Terminal 1)
3. Run `./start-backend.sh` (Terminal 2)
4. Run `./start-frontend.sh` (Terminal 3)
5. Access http://localhost:3000

## Verification Commands

```bash
# Test Elasticsearch
curl -u elastic:infini_rag_flow http://localhost:1200

# Test MySQL
~/ragflow-services/mysql-8.0.39-linux-glibc2.28-x86_64/bin/mysql \
  --socket=/tmp/mysql_ragflow.sock -u root -p'infini_rag_flow' \
  -e 'SHOW DATABASES;'

# Test Redis
~/ragflow-services/redis-7.2.4/src/redis-cli -a 'infini_rag_flow' ping

# Check all ports
netstat -tuln | grep -E '1200|5455|6379|9000|9001|9380|3000'
```

## Session Result
Successfully configured RAGFlow for local development without Docker, with all services running natively on the host machine. The setup provides full flexibility for customization and development.