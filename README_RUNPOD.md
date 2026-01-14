# RAGFlow on RunPod - Deployment Guide

This guide explains how to deploy and run RAGFlow on [RunPod](https://runpod.io) using the `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04` image.

## 📋 Prerequisites

- A RunPod account with GPU pod access
- At least 50GB of storage (recommend using persistent volume)
- Minimum 16GB RAM recommended
- GPU with CUDA support (the image includes CUDA 12.4.1)

## 🚀 Quick Start

### 1. Create a RunPod Pod

1. Go to [RunPod](https://runpod.io) and create a new pod
2. Select the template: `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04`
3. Choose a GPU (RTX 3090, RTX 4090, A100, etc.)
4. Configure storage:
   - **Container Disk**: 50GB minimum
   - **Volume Disk**: 100GB+ recommended (for persistent data)
5. Expose the following ports:
   - `9222` - Frontend (HTTP)
   - `9380` - Backend API (HTTP)
   - `9001` - MinIO Console (HTTP, optional)

### 2. Clone the Repository

Connect to your pod via web terminal or SSH, then:

```bash
cd /workspace
git clone https://github.com/infiniflow/ragflow.git
cd ragflow
```

### 3. One-Command Setup and Start (Recommended)

**NEW:** For the easiest out-of-the-box experience, use the all-in-one script:

```bash
bash setup_and_start_runpod.sh
```

This single script will:
- Install all system dependencies (MySQL, Redis, MinIO, Elasticsearch)
- Set up Python environment with uv
- Download required models and dependencies
- Install frontend dependencies
- Create configuration files
- Start all infrastructure services with proper verification
- Start the RAGFlow backend
- Start the frontend development server
- Verify GPU availability

**Note:** This process takes 10-30 minutes depending on network speed.

### Alternative: Two-Step Setup

If you prefer to separate setup from startup, use the traditional approach:

#### Step 3a: Run Setup

```bash
bash setup_runpod.sh
```

This will:
- Install system dependencies (MySQL, Redis, MinIO, Elasticsearch)
- Set up Python environment with uv
- Download required models and dependencies
- Install frontend dependencies
- Create configuration files

**Note:** This process takes 10-30 minutes depending on network speed.

#### Step 3b: Start RAGFlow

```bash
bash start_ragflow_runpod.sh
```

This will:
- Start all infrastructure services
- Start the RAGFlow backend
- Start the frontend development server
- Verify GPU availability

### 5. Access the Application

- **Frontend**: `http://<pod-ip>:9222`
- **Backend API**: `http://<pod-ip>:9380`
- **MinIO Console**: `http://<pod-ip>:9001`

In RunPod, you can find the access URLs in your pod's "Connect" menu.

## 📁 Directory Structure

```
/workspace/
├── ragflow/                  # Application code
│   ├── .venv/               # Python virtual environment
│   ├── logs/                # Application logs
│   ├── web/                 # Frontend source
│   └── ...
└── ragflow-data/            # Persistent data (on volume)
    ├── mysql/               # MySQL data
    ├── redis/               # Redis data
    ├── minio/               # Object storage
    ├── elasticsearch/       # Search index
    ├── logs/                # Service logs
    └── pids/                # Process IDs
```

## 🔧 Configuration

### Environment Variables

Copy and modify the example configuration:

```bash
cp .env.runpod.example .env
nano .env
```

Key settings:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATA_DIR` | `/workspace/ragflow-data` | Persistent data directory |
| `MYSQL_PORT` | `5455` | MySQL port |
| `REDIS_PORT` | `6379` | Redis port |
| `ES_PORT` | `1200` | Elasticsearch port |
| `WS` | `1` | Number of task executor workers |

### LLM Configuration

Configure your preferred LLM provider in `.env` or via the web UI:

```bash
# OpenAI
OPENAI_API_KEY=sk-xxxxxxxxxxxxx

# Or Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

## 📜 Available Scripts

| Script | Description |
|--------|-------------|
| `setup_and_start_runpod.sh` | **NEW:** All-in-one setup and start (recommended for first time) |
| `setup_runpod.sh` | Initial setup only (run once) |
| `start_ragflow_runpod.sh` | Start all services |
| `stop_ragflow_runpod.sh` | Stop RAGFlow (keep infrastructure) |
| `stop_ragflow_runpod.sh --stop-infra` | Stop everything |
| `start_infrastructure_runpod.sh` | Start only infrastructure |

## 🔍 Monitoring & Logs

### View Application Logs

```bash
# Backend logs
tail -f logs/ragflow_server.log

# Task executor logs
tail -f logs/task_executor_0.log
```

### View Service Logs

```bash
# All service logs
ls /workspace/ragflow-data/logs/

# Specific service
tail -f /workspace/ragflow-data/logs/mysql.log
tail -f /workspace/ragflow-data/logs/elasticsearch.log
```

### Check GPU Usage

```bash
# GPU status
nvidia-smi

# Real-time monitoring
watch -n 1 nvidia-smi
```

### Check Service Status

```bash
# Check ports
lsof -i :5455  # MySQL
lsof -i :6379  # Redis
lsof -i :9000  # MinIO
lsof -i :1200  # Elasticsearch
lsof -i :9380  # Backend
lsof -i :9222  # Frontend
```

## 🔄 Persistence

Data stored in `/workspace/ragflow-data/` persists across pod restarts when using a RunPod volume.

After a pod restart:
1. The data directory is preserved on the volume
2. Simply run `bash start_ragflow_runpod.sh` to restart services
3. All your knowledge bases, documents, and settings are retained

## 🆘 Troubleshooting

### Permission Warnings During Setup

If you see warnings like:
```
Warning: Could not change ownership to mysql user
Running MySQL as root instead (common in containerized environments)
```

This is **normal** in RunPod containers. The setup scripts automatically detect when ownership changes fail (common with mounted volumes) and safely run services as root instead. This doesn't affect functionality.

### Services Won't Start

Check if ports are already in use:
```bash
lsof -i :5455 -i :6379 -i :9000 -i :1200
```

Kill any stale processes:
```bash
bash stop_ragflow_runpod.sh --stop-infra
```

### Out of Memory

Reduce Elasticsearch heap size by editing:
```bash
nano /opt/elasticsearch/config/jvm.options.d/heap.options
```

Change `-Xms2g -Xmx2g` to `-Xms1g -Xmx1g`.

### GPU Not Detected

Verify CUDA is available:
```bash
source .venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"
```

### Connection Refused Errors

Ensure hosts file has correct entries:
```bash
cat /etc/hosts | grep -E "es01|mysql|minio|redis"
```

If missing, run:
```bash
echo "127.0.0.1 es01 infinity mysql minio redis sandbox-executor-manager" >> /etc/hosts
```

### Elasticsearch Won't Start

Check Elasticsearch logs:
```bash
tail -100 /workspace/ragflow-data/logs/elasticsearch/ragflow-cluster.log
```

Common fix - increase vm.max_map_count (if you have root access):
```bash
sysctl -w vm.max_map_count=262144
```

## 🔐 Default Credentials

All services use the password: `infini_rag_flow`

| Service | Username | Password |
|---------|----------|----------|
| MySQL | root | infini_rag_flow |
| Redis | - | infini_rag_flow |
| MinIO | rag_flow | infini_rag_flow |
| Elasticsearch | elastic | infini_rag_flow |

**Security Note:** For production use, change these passwords in `.env` before running setup.

## 📊 Resource Requirements

| Component | Memory | Disk |
|-----------|--------|------|
| MySQL | ~500MB | Variable |
| Redis | ~128MB | Variable |
| MinIO | ~200MB | Variable |
| Elasticsearch | 2GB | Variable |
| RAGFlow Backend | ~2-4GB | - |
| Frontend | ~500MB | - |

**Total Recommended:** 16GB+ RAM, 50GB+ disk

## 🎯 Next Steps

After starting RAGFlow:

1. **Register an Account**: Open the frontend URL and create an account
2. **Configure LLM**: Go to Settings and add your LLM API keys
3. **Create Knowledge Base**: Upload your documents
4. **Start Chatting**: Create a chat assistant and query your documents

## 📚 Additional Resources

- [RAGFlow Documentation](https://ragflow.io/docs)
- [RAGFlow GitHub](https://github.com/infiniflow/ragflow)
- [RunPod Documentation](https://docs.runpod.io)

## 🤝 Support

For issues specific to the RunPod deployment:
- Check the logs in `/workspace/ragflow-data/logs/`
- Review this troubleshooting guide
- Open an issue on GitHub with your logs

---

**Quick Reference:**

```bash
# One-command setup and start (first time)
bash setup_and_start_runpod.sh

# Or start everything (after setup)
bash start_ragflow_runpod.sh

# Stop RAGFlow only
bash stop_ragflow_runpod.sh

# Stop everything
bash stop_ragflow_runpod.sh --stop-infra

# View logs
tail -f logs/ragflow_server.log
```
