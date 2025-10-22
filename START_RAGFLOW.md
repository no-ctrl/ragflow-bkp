# RAGFlow Local Startup Guide

This guide provides instructions for starting RAGFlow locally without Docker, using GPU acceleration.

## Prerequisites

- WSL2 with Ubuntu 24.04
- NVIDIA GPU with CUDA support
- Python 3.11+ installed
- Node.js and npm installed
- All infrastructure services installed (MySQL, Redis, MinIO, Elasticsearch)

## Quick Start

### Option 1: Automated Startup (Recommended)

Run the startup script:

```bash
cd ~/projects/ragflow
bash start_ragflow.sh
```

This will:
1. Verify all infrastructure services are running
2. Activate the Python virtual environment
3. Start the backend services (task executor + API server)
4. Start the frontend development server
5. Display the application URL

### Option 2: Manual Startup

#### Step 1: Start Infrastructure Services

Ensure all required services are running:

```bash
# Check service status
sudo systemctl status mysql redis-server minio elasticsearch

# Start any stopped services
sudo systemctl start mysql redis-server minio elasticsearch
```

#### Step 2: Activate Virtual Environment

```bash
cd ~/projects/ragflow

# Deactivate conda if active
conda deactivate

# Activate uv virtual environment
source .venv/bin/activate
```

#### Step 3: Start Backend Services

Open a terminal and run:

```bash
cd ~/projects/ragflow
source .venv/bin/activate
export PYTHONPATH=$(pwd)
bash launch_backend_service.sh
```

You should see:
```
* Running on http://127.0.0.1:9380
```

**Keep this terminal open** - the backend runs in the foreground.

#### Step 4: Start Frontend Development Server

Open a **new terminal** and run:

```bash
cd ~/projects/ragflow/web
npm run dev
```

You should see:
```
ready - started server on 0.0.0.0:9222
```

**Keep this terminal open** - the frontend runs in the foreground.

#### Step 5: Access the Application

Open your browser and navigate to:

**http://localhost:9222**

## Verification

### Check Infrastructure Services

```bash
# MySQL
mysql -u root -pinfini_rag_flow -h 127.0.0.1 -P 5455 -e "SELECT 1"

# Redis
redis-cli -a infini_rag_flow ping

# MinIO
curl -s http://127.0.0.1:9000/minio/health/live

# Elasticsearch
curl -s -u elastic:infini_rag_flow http://127.0.0.1:1200
```

### Check Backend API

```bash
curl -s http://127.0.0.1:9380/v1/system/version
```

Should return JSON with version info (may show 401 Unauthorized, which is normal).

### Check GPU Usage

```bash
nvidia-smi
```

You should see Python processes using GPU memory (~2GB).

### Check Logs

```bash
# Backend logs
tail -f ~/projects/ragflow/logs/ragflow_server.log
tail -f ~/projects/ragflow/logs/task_executor_0.log
```

## Stopping the Application

### Stop Frontend

In the frontend terminal, press **Ctrl+C**

### Stop Backend

In the backend terminal, press **Ctrl+C**

The script will gracefully shut down both the API server and task executor.

### Stop Infrastructure (Optional)

If you want to stop all infrastructure services:

```bash
sudo systemctl stop mysql redis-server minio elasticsearch
```

## Troubleshooting

### Backend Won't Start

**Issue**: "Failed to connect to Redis/MySQL/Elasticsearch"

**Solution**: Verify infrastructure services are running:
```bash
sudo systemctl status mysql redis-server minio elasticsearch
```

Start any stopped services:
```bash
sudo systemctl start <service-name>
```

### Redis Errors: "can't persist to disk"

**Solution**: Check Redis logs and fix permissions:
```bash
sudo journalctl -u redis-server -n 50
sudo chown -R redis:redis /var/lib/redis
sudo systemctl restart redis-server
```

### GPU Not Detected

**Solution**: Verify NVIDIA drivers and CUDA:
```bash
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
```

### Port Already in Use

**Issue**: "Address already in use" on port 9380 or 9222

**Solution**: Find and kill the process using the port:
```bash
# For backend (port 9380)
lsof -ti:9380 | xargs kill -9

# For frontend (port 9222)
lsof -ti:9222 | xargs kill -9
```

### Conda Environment Interference

**Issue**: Wrong Python/pip being used

**Solution**: Deactivate conda before activating uv venv:
```bash
conda deactivate
source .venv/bin/activate
which python  # Should show .venv/bin/python
```

## Service Configuration

### Infrastructure Service Ports

| Service       | Port | Username | Password           |
|---------------|------|----------|--------------------|
| MySQL         | 5455 | root     | infini_rag_flow    |
| Redis         | 6379 | -        | infini_rag_flow    |
| MinIO API     | 9000 | rag_flow | infini_rag_flow    |
| MinIO Console | 9001 | rag_flow | infini_rag_flow    |
| Elasticsearch | 1200 | elastic  | infini_rag_flow    |

### Application Ports

| Service        | Port | URL                       |
|----------------|------|---------------------------|
| Backend API    | 9380 | http://127.0.0.1:9380     |
| Frontend       | 9222 | http://localhost:9222     |

## GPU Configuration

The application uses GPU for:
- **Embedding models**: BAAI/bge-large-zh-v1.5, BAAI/bge-reranker-v2-m3
- **OCR**: Document detection and recognition
- **Layout analysis**: Document structure understanding

Expected GPU memory usage: ~2-3GB idle, up to 10GB during heavy processing.

## Environment Variables

Key environment variables (set automatically by the startup script):

```bash
PYTHONPATH=$(pwd)                    # Python module search path
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/  # Library path for jemalloc
```

## First-Time Setup Reminder

If this is a fresh installation or after updates, you may need to:

1. **Update Python dependencies**:
   ```bash
   source .venv/bin/activate
   uv sync --all-extras
   ```

2. **Download AI models** (if missing):
   ```bash
   python download_deps.py
   ```

3. **Reset infrastructure passwords** (if authentication fails):
   ```bash
   # Elasticsearch
   sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i
   ```

## Performance Tips

1. **GPU Memory**: Monitor with `nvidia-smi`. If running out of memory, reduce batch sizes or close other GPU applications.

2. **Database Connections**: The default MySQL max_connections is 1000. Adjust in `/etc/mysql/mysql.conf.d/mysqld.cnf` if needed.

3. **Redis Memory**: Default is 128MB. Adjust `maxmemory` in `/etc/redis/redis.conf` for larger workloads.

4. **Frontend Hot Reload**: The development server watches for file changes. For production, build with `npm run build`.

## Next Steps

After starting the application:

1. **Create an account** at http://localhost:9222
2. **Configure LLM providers** (OpenAI, Azure, etc.) in Settings
3. **Create a knowledge base** and upload documents
4. **Create a chat assistant** and start querying your documents

## Additional Resources

- RAGFlow Documentation: https://ragflow.io/docs
- GitHub Issues: https://github.com/infiniflow/ragflow/issues
- Configuration: `conf/service_conf.yaml`
- Logs: `logs/` directory
