# RAGFlow Local Setup Summary

This document summarizes the complete setup process for running RAGFlow locally without Docker, with full GPU acceleration.

## What Was Done

### 1. Infrastructure Setup (WSL2 Native)

Installed and configured all required services directly on WSL2 Ubuntu:

- **MySQL 8.0** (port 5455)
  - Database: `rag_flow`
  - User: `root`
  - Password: `infini_rag_flow`
  - Custom configuration for RAGFlow workloads

- **Redis/Valkey** (port 6379)
  - Password: `infini_rag_flow`
  - Working directory: `/var/lib/redis`
  - Memory limit: 128MB with LRU eviction

- **MinIO** (ports 9000/9001)
  - User: `rag_flow`
  - Password: `infini_rag_flow`
  - Data directory: `/mnt/minio/data`

- **Elasticsearch 8.11.3** (port 1200)
  - User: `elastic`
  - Password: `infini_rag_flow`
  - Single-node configuration
  - Heap size: 2GB

All services configured as systemd services with auto-start on boot.

### 2. Python Environment Setup

- **Virtual Environment**: uv-managed Python 3.12 venv
- **Location**: `~/projects/ragflow/.venv`

**GPU Packages Installed:**
- PyTorch 2.5.0+cu121 (CUDA 12.1 support)
- ONNX Runtime GPU 1.19.2
- Transformers 4.x
- FlagEmbedding 1.2.10
- BCEmbedding 0.1.5
- FastEmbed GPU

**Total GPU Memory Usage**: ~2-3GB idle, up to 10GB during processing

### 3. Configuration Changes

**File: `conf/service_conf.yaml`**

Changed:
```yaml
ragflow:
  host: 0.0.0.0  # Was: ${RAGFLOW_HOST:-0.0.0.0}
  http_port: 9380
```

This fixed the backend server binding issue.

**File: `/etc/redis/redis.conf`**

Added:
```
dir /var/lib/redis
dbfilename dump.rdb
```

This fixed Redis persistence errors.

### 4. AI Models Downloaded

All required models downloaded via `download_deps.py`:
- Embedding models (BAAI/bge-large-zh-v1.5, etc.)
- Reranking models (BAAI/bge-reranker-v2-m3)
- OCR models (detection, recognition)
- Layout analysis models (paper, laws, manual, general)
- Table structure recognition models

**Storage**: `~/.cache/huggingface/` and `rag/res/`

### 5. Scripts Created

**`start_ragflow.sh`** - Automated startup script
- Checks and starts infrastructure services
- Verifies service connectivity
- Starts backend in background
- Starts frontend in background
- Verifies GPU usage
- Displays access URLs

**`stop_ragflow.sh`** - Graceful shutdown script
- Stops backend processes
- Stops frontend process
- Optionally stops infrastructure services

**`setup_infrastructure_wsl2.sh`** - Initial infrastructure setup
- Installs MySQL, Redis, MinIO, Elasticsearch
- Configures all services
- Sets passwords and permissions

**`install_gpu_packages.sh`** - GPU package installation (deprecated)
- Initially used for manual GPU package installation
- Superseded by direct pip commands

### 6. Documentation Created

**`START_RAGFLOW.md`** - Complete startup guide
- Quick start instructions
- Manual startup steps
- Verification commands
- Troubleshooting guide

**`QUICK_REFERENCE.md`** - Command reference
- Common commands
- Service endpoints
- Troubleshooting shortcuts
- Maintenance tasks

**`SETUP_SUMMARY.md`** - This document
- Complete setup overview
- What was installed
- Configuration changes

## Current State

### Services Running

```
✓ MySQL          127.0.0.1:5455
✓ Redis          127.0.0.1:6379
✓ MinIO          127.0.0.1:9000 (API), 127.0.0.1:9001 (Console)
✓ Elasticsearch  127.0.0.1:1200
✓ RAGFlow API    127.0.0.1:9380
✓ RAGFlow UI     localhost:9222
```

### GPU Status

```
NVIDIA GeForce RTX 4090
- Driver: 580.97
- CUDA: 13.0
- Memory: 2107MB / 24564MB in use
- Processes: ragflow_server.py, task_executor.py
```

### Application Status

- ✅ Backend API responsive
- ✅ Frontend accessible at http://localhost:9222
- ✅ User registration/login working
- ✅ GPU models loaded (OCR, embeddings)
- ✅ Database connectivity verified
- ✅ All infrastructure services healthy

## Key Learnings

### Issues Encountered and Resolved

1. **Docker not available in WSL2**
   - Solution: Install infrastructure natively using systemd

2. **GPU package installation timeout**
   - Solution: Install large packages (PyTorch) first, then run `uv sync`

3. **Virtual environment conflicts**
   - Issue: Conda environment interfered with uv venv
   - Solution: Always deactivate conda first

4. **Backend server not binding**
   - Issue: `host: ${RAGFLOW_HOST:-0.0.0.0}` not resolved
   - Solution: Changed to `host: 0.0.0.0` directly

5. **Redis persistence errors**
   - Issue: Redis trying to write to `/` (root directory)
   - Solution: Added `dir /var/lib/redis` to config

6. **Missing system dependencies**
   - pkg-config, libjemalloc-dev, python3.12-dev
   - Solution: Installed via apt

7. **Module not found: datrie**
   - Issue: Not included in uv sync
   - Solution: Installed separately with `uv pip install datrie`

8. **Module not found: exceptiongroup**
   - Issue: Missing for task_executor
   - Solution: Installed with `uv pip install exceptiongroup`

## Architecture

### Deployment Model

**Hybrid Architecture**: Native infrastructure + Local Python application

```
┌─────────────────────────────────────────┐
│          WSL2 Ubuntu 24.04              │
├─────────────────────────────────────────┤
│  Infrastructure (systemd services)      │
│  ├─ MySQL 8.0         (port 5455)      │
│  ├─ Redis/Valkey      (port 6379)      │
│  ├─ MinIO             (port 9000/9001) │
│  └─ Elasticsearch     (port 1200)      │
├─────────────────────────────────────────┤
│  RAGFlow Backend (Python, GPU-enabled)  │
│  ├─ API Server        (port 9380)      │
│  └─ Task Executor     (background)     │
├─────────────────────────────────────────┤
│  RAGFlow Frontend (Node.js)             │
│  └─ Dev Server        (port 9222)      │
├─────────────────────────────────────────┤
│  GPU Resources                          │
│  └─ NVIDIA RTX 4090   (24GB VRAM)      │
└─────────────────────────────────────────┘
```

### Why This Approach?

1. **GPU Access**: Direct GPU access from Python without Docker overhead
2. **Performance**: Native services perform better than containers in WSL2
3. **Simplicity**: Easier debugging and log access
4. **Flexibility**: Easy to update individual components

## Next Time Startup

### Automatic (Recommended)

```bash
cd ~/projects/ragflow
bash start_ragflow.sh
```

### Manual

1. Ensure infrastructure is running
2. Deactivate conda: `conda deactivate`
3. Start backend:
   ```bash
   cd ~/projects/ragflow
   source .venv/bin/activate
   export PYTHONPATH=$(pwd)
   bash docker/launch_backend_service.sh
   ```
4. Start frontend (new terminal):
   ```bash
   cd ~/projects/ragflow/web
   npm run dev
   ```

## Resource Usage

### Disk Space

- Python environment: ~8GB
- AI models: ~5GB
- Elasticsearch data: varies with usage
- MySQL data: varies with usage
- Total: ~15GB + data

### Memory

- Infrastructure services: ~3-4GB
- RAGFlow backend: ~2-3GB
- GPU memory: ~2-3GB idle, up to 10GB processing

### Ports Used

| Port | Service           |
|------|-------------------|
| 1200 | Elasticsearch     |
| 5455 | MySQL             |
| 6379 | Redis             |
| 9000 | MinIO API         |
| 9001 | MinIO Console     |
| 9222 | Frontend Dev      |
| 9380 | Backend API       |

## Maintenance

### Regular Tasks

1. **Monitor logs**: Check for errors in `logs/` directory
2. **GPU monitoring**: Run `nvidia-smi` to check usage
3. **Disk space**: Ensure adequate space for documents
4. **Updates**: Periodically run `uv sync --all-extras`

### Backup Recommendations

Important data to backup:
- MySQL database: `/var/lib/mysql/`
- MinIO data: `/mnt/minio/data/`
- Elasticsearch data: `/var/lib/elasticsearch/`
- Configuration: `conf/service_conf.yaml`

### Updates

```bash
# Stop application
bash stop_ragflow.sh

# Update code
git pull

# Update dependencies
source .venv/bin/activate
uv sync --all-extras

# Download new models (if any)
python download_deps.py

# Restart
bash start_ragflow.sh
```

## Support

### Documentation
- Start guide: `START_RAGFLOW.md`
- Quick reference: `QUICK_REFERENCE.md`
- RAGFlow docs: https://ragflow.io/docs

### Logs Location
- Backend: `~/projects/ragflow/logs/ragflow_server.log`
- Task executor: `~/projects/ragflow/logs/task_executor_0.log`
- Infrastructure: `sudo journalctl -u <service-name>`

### Common Issues
See `START_RAGFLOW.md` troubleshooting section

## Success Metrics

✅ All infrastructure services running and accessible
✅ Python environment with GPU support operational
✅ Backend API responding to requests
✅ Frontend accessible and functional
✅ GPU being utilized for ML tasks
✅ User registration/login working
✅ Document upload capability available
✅ All AI models loaded and ready

## Total Setup Time

- Infrastructure setup: ~15 minutes
- Python environment: ~20 minutes (includes downloads)
- AI models download: ~10 minutes
- Configuration and troubleshooting: ~30 minutes
- **Total: ~75 minutes** (one-time setup)

**Next startup: ~30 seconds** (using automated script)

---

**Setup Date**: October 9, 2025
**RAGFlow Version**: 51bbcdb2 (full)
**Environment**: WSL2 Ubuntu 24.04.3, Python 3.12, CUDA 13.0
**GPU**: NVIDIA GeForce RTX 4090 (24GB)
