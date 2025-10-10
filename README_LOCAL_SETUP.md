# RAGFlow Local Setup - Documentation Index

This directory contains complete documentation and automation scripts for running RAGFlow locally without Docker, with full GPU acceleration.

## 📚 Documentation Files

### Quick Start
- **[START_RAGFLOW.md](START_RAGFLOW.md)** - Complete startup guide with step-by-step instructions
  - Automated and manual startup methods
  - Verification steps
  - Troubleshooting guide

### Reference
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Command reference and shortcuts
  - Common commands
  - Service endpoints
  - Troubleshooting snippets
  - Maintenance tasks

### Setup Information
- **[SETUP_SUMMARY.md](SETUP_SUMMARY.md)** - Complete setup documentation
  - What was installed and configured
  - Architecture overview
  - Issues encountered and solutions
  - Resource requirements

## 🚀 Scripts

### Production Use
- **`start_ragflow.sh`** ⭐ - Automated startup script (RECOMMENDED)
  ```bash
  bash start_ragflow.sh
  ```
  - Checks and starts all infrastructure services
  - Starts RAGFlow backend and frontend
  - Verifies GPU usage
  - Displays access URLs

- **`stop_ragflow.sh`** - Graceful shutdown script
  ```bash
  bash stop_ragflow.sh
  ```
  - Stops RAGFlow processes
  - Optionally stops infrastructure

### Setup Scripts (One-time use)
- **`setup_infrastructure_wsl2.sh`** - Infrastructure installation script
  - Already run during initial setup
  - Installs MySQL, Redis, MinIO, Elasticsearch
  - Only needed for fresh installations

## 🎯 Quick Start Guide

### First Time After Reboot

```bash
cd ~/projects/ragflow
bash start_ragflow.sh
```

Then open: **http://localhost:9222**

### Stopping the Application

```bash
cd ~/projects/ragflow
bash stop_ragflow.sh
```

### Manual Startup (if needed)

See [START_RAGFLOW.md](START_RAGFLOW.md) for detailed manual startup instructions.

## 📊 System Overview

### Services

| Service       | Port | Status Check |
|---------------|------|--------------|
| MySQL         | 5455 | `sudo systemctl status mysql` |
| Redis         | 6379 | `sudo systemctl status redis-server` |
| MinIO         | 9000 | `sudo systemctl status minio` |
| Elasticsearch | 1200 | `sudo systemctl status elasticsearch` |
| RAGFlow API   | 9380 | `curl http://127.0.0.1:9380/v1/system/version` |
| Frontend      | 9222 | Open http://localhost:9222 |

### GPU Usage

```bash
# Monitor GPU
nvidia-smi

# Watch in real-time
watch -n 1 nvidia-smi
```

Expected: ~2-3GB GPU memory usage (idle)

## 📝 Logs

### Application Logs
```bash
# Backend
tail -f logs/ragflow_server.log

# Task executor
tail -f logs/task_executor_0.log
```

### Infrastructure Logs
```bash
# MySQL
sudo journalctl -u mysql -f

# Redis
sudo journalctl -u redis-server -f

# Elasticsearch
sudo journalctl -u elasticsearch -f
```

## 🔧 Common Tasks

### Restart Everything
```bash
bash stop_ragflow.sh  # Answer 'y' to stop infrastructure
bash start_ragflow.sh
```

### Check Service Status
```bash
sudo systemctl status mysql redis-server minio elasticsearch
```

### View GPU Usage
```bash
nvidia-smi
```

### Update Dependencies
```bash
source .venv/bin/activate
uv sync --all-extras
```

## 🆘 Troubleshooting

### Application won't start

1. Check infrastructure services:
   ```bash
   sudo systemctl status mysql redis-server minio elasticsearch
   ```

2. Check logs:
   ```bash
   tail -100 logs/ragflow_server.log
   ```

3. Verify ports are not in use:
   ```bash
   lsof -i:9380  # Backend
   lsof -i:9222  # Frontend
   ```

### GPU not working

```bash
# Verify GPU is available
nvidia-smi

# Test PyTorch CUDA
source .venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"
```

### More troubleshooting

See detailed troubleshooting guide in [START_RAGFLOW.md](START_RAGFLOW.md)

## 📁 Directory Structure

```
~/projects/ragflow/
├── README_LOCAL_SETUP.md       # This file
├── START_RAGFLOW.md            # Complete startup guide
├── QUICK_REFERENCE.md          # Command reference
├── SETUP_SUMMARY.md            # Setup documentation
│
├── start_ragflow.sh ⭐          # Start script (use this!)
├── stop_ragflow.sh             # Stop script
├── setup_infrastructure_wsl2.sh # Infrastructure setup
│
├── .venv/                      # Python virtual environment
├── web/                        # Frontend source
├── api/                        # Backend API source
├── rag/                        # RAG engine
├── logs/                       # Application logs
└── conf/                       # Configuration files
    └── service_conf.yaml       # Service configuration
```

## 🔐 Default Credentials

All services use the password: `infini_rag_flow`

| Service       | Username | Password         |
|---------------|----------|------------------|
| MySQL         | root     | infini_rag_flow  |
| Redis         | -        | infini_rag_flow  |
| MinIO         | rag_flow | infini_rag_flow  |
| Elasticsearch | elastic  | infini_rag_flow  |

## 📚 Additional Resources

- RAGFlow Official Docs: https://ragflow.io/docs
- GitHub Repository: https://github.com/infiniflow/ragflow
- Issues: https://github.com/infiniflow/ragflow/issues

## ⚡ Performance Tips

1. **GPU Memory**: Monitor with `nvidia-smi`. RTX 4090 with 24GB is excellent for this workload.

2. **First Use**: First document upload will be slower as models initialize.

3. **Development**: Frontend runs in dev mode with hot reload. For production, use `npm run build`.

4. **Database**: MySQL is configured with 1000 max connections - adjust if needed.

## 🎓 Next Steps

After starting the application:

1. **Create Account**: Register at http://localhost:9222
2. **Configure LLM**: Add your OpenAI/Azure API keys in Settings
3. **Create Knowledge Base**: Upload your documents
4. **Create Chat Assistant**: Start querying your documents

---

**For detailed information, see:**
- 🚀 **Getting Started**: [START_RAGFLOW.md](START_RAGFLOW.md)
- 📖 **Commands**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- 🔍 **Setup Details**: [SETUP_SUMMARY.md](SETUP_SUMMARY.md)

**Quick Start**: `bash start_ragflow.sh` → Open http://localhost:9222
