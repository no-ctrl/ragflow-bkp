# RAGFlow RunPod - Quick Reference Card

## 🚀 One-Command Installation

```bash
cd /workspace
git clone https://github.com/infiniflow/ragflow.git
cd ragflow
bash setup_and_start_runpod.sh
```

**Time**: 10-30 minutes (depending on network speed)  
**Result**: Fully running RAGFlow with all services

---

## 📍 Access URLs

After successful startup:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://localhost:9222 | Create account on first visit |
| **Backend API** | http://127.0.0.1:9380 | - |
| **MinIO Console** | http://127.0.0.1:9001 | rag_flow / infini_rag_flow |
| **MySQL** | 127.0.0.1:5455 | root / infini_rag_flow |
| **Redis** | 127.0.0.1:6379 | infini_rag_flow |
| **Elasticsearch** | http://127.0.0.1:1200 | elastic / infini_rag_flow |

---

## 🔄 After Pod Restart

```bash
cd /workspace/ragflow
bash setup_and_start_runpod.sh  # Idempotent - safe to re-run
```

---

## 🛑 Stop RAGFlow

```bash
# Stop RAGFlow only (keep infrastructure running)
bash stop_ragflow_runpod.sh

# Stop everything (infrastructure + RAGFlow)
bash stop_ragflow_runpod.sh --stop-infra
```

---

## 📊 Check Status

```bash
# Check if services are running
lsof -i :5455  # MySQL
lsof -i :6379  # Redis
lsof -i :9000  # MinIO
lsof -i :1200  # Elasticsearch
lsof -i :9380  # Backend
lsof -i :9222  # Frontend

# Check GPU
nvidia-smi
```

---

## 📝 View Logs

```bash
# Application logs
tail -f logs/ragflow_server.log          # Backend
tail -f /workspace/ragflow-data/logs/frontend.log  # Frontend

# Service logs
tail -f /workspace/ragflow-data/logs/mysql.log
tail -f /workspace/ragflow-data/logs/redis.log
tail -f /workspace/ragflow-data/logs/minio.log
tail -f /workspace/ragflow-data/logs/elasticsearch-startup.log

# List all logs
ls -lh /workspace/ragflow-data/logs/
```

---

## 🐛 Troubleshooting

### MinIO won't start
```bash
# Check MinIO log
tail -50 /workspace/ragflow-data/logs/minio.log

# Check if port is in use
lsof -i :9000

# Restart MinIO
pkill minio
# Then re-run setup script
```

### Backend won't start
```bash
# Check backend log
tail -50 logs/ragflow_server.log

# Check if virtual environment exists
ls -la .venv/

# Check Python version
.venv/bin/python --version
```

### Services won't connect
```bash
# Verify /etc/hosts
cat /etc/hosts | grep -E "es01|mysql|minio|redis"

# Should show:
# 127.0.0.1 es01 infinity mysql minio redis sandbox-executor-manager
```

### Out of disk space
```bash
# Check disk usage
df -h /workspace

# Clean up if needed
rm -rf /tmp/*
docker system prune -a  # If using Docker
```

---

## 💾 Data Persistence

All data is stored in `/workspace/ragflow-data/`:

```
/workspace/ragflow-data/
├── mysql-backup/      # MySQL data backup
├── redis/            # Redis persistence
├── minio/            # Object storage (documents)
├── elasticsearch/    # Search indexes
├── logs/             # Service logs
└── pids/             # Process IDs
```

**Important**: Use RunPod's persistent volume to preserve data across pod restarts.

---

## 🔐 Change Default Passwords

Edit `.env` before running setup:

```bash
nano .env

# Change these:
MYSQL_PASSWORD=your_secure_password
REDIS_PASSWORD=your_secure_password
MINIO_PASSWORD=your_secure_password
ES_PASSWORD=your_secure_password
```

Then run setup script.

---

## 🆘 Emergency Recovery

### Clean slate (WARNING: Deletes all data)
```bash
# Stop everything
bash stop_ragflow_runpod.sh --stop-infra

# Remove data
rm -rf /workspace/ragflow-data/*

# Start fresh
bash setup_and_start_runpod.sh
```

### Kill stuck processes
```bash
# Find processes
ps aux | grep -E "mysql|redis|minio|elasticsearch|ragflow"

# Kill by PID
kill -9 <PID>

# Or kill all
pkill -9 mysqld
pkill -9 redis-server
pkill -9 minio
pkill -9 elasticsearch
pkill -9 -f ragflow_server.py
```

---

## 📚 Documentation

- **Full Guide**: [README_RUNPOD.md](README_RUNPOD.md)
- **Technical Fix Details**: [RUNPOD_SETUP_FIX.md](RUNPOD_SETUP_FIX.md)
- **Before/After Comparison**: [BEFORE_AFTER_COMPARISON.md](BEFORE_AFTER_COMPARISON.md)
- **Main README**: [README.md](README.md)

---

## ⚡ Quick Commands Cheat Sheet

```bash
# Setup and start (first time or after restart)
bash setup_and_start_runpod.sh

# Stop RAGFlow only
bash stop_ragflow_runpod.sh

# Stop everything
bash stop_ragflow_runpod.sh --stop-infra

# View backend logs
tail -f logs/ragflow_server.log

# View all service logs
ls /workspace/ragflow-data/logs/

# Check GPU
nvidia-smi

# Test MySQL connection
MYSQL_PWD="infini_rag_flow" mysql -u root -h 127.0.0.1 -P 5455 -e "SELECT 1"

# Test Redis connection
REDISCLI_AUTH="infini_rag_flow" redis-cli -p 6379 ping

# Test Elasticsearch
curl -u elastic:infini_rag_flow http://127.0.0.1:1200

# Test MinIO
curl http://127.0.0.1:9000/minio/health/live
```

---

## 💡 Pro Tips

1. **First Time Setup**: Expect 10-30 minutes for downloads and compilation
2. **Pod Restart**: Just run `bash setup_and_start_runpod.sh` again (idempotent)
3. **Logs**: Always check `/workspace/ragflow-data/logs/` when debugging
4. **GPU**: Run `nvidia-smi` to verify GPU is detected
5. **Persistent Volume**: Use RunPod volume for `/workspace` to keep data
6. **Port Conflicts**: If ports are in use, stop services first
7. **Memory**: Minimum 16GB RAM recommended, adjust ES heap if needed

---

## ✅ Success Indicators

You'll know everything is working when you see:

```
========================================
RAGFlow is Ready!
========================================

Application URLs:
  Frontend:      http://localhost:9222
  Backend API:   http://127.0.0.1:9380

✓ MySQL is accessible
✓ Redis is accessible
✓ MinIO is accessible
✓ Elasticsearch is accessible
✓ PyTorch CUDA is available

Open your browser to: http://localhost:9222
```

---

**Need Help?** Check the logs in `/workspace/ragflow-data/logs/` or consult the full documentation.
