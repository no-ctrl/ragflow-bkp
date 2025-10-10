# RAGFlow Quick Reference

## Starting RAGFlow

```bash
cd ~/projects/ragflow
bash start_ragflow.sh
```

Then open: **http://localhost:9222**

## Stopping RAGFlow

```bash
cd ~/projects/ragflow
bash stop_ragflow.sh
```

## Manual Commands

### Start Services Manually

```bash
# 1. Deactivate conda (if active)
conda deactivate

# 2. Start backend (in one terminal)
cd ~/projects/ragflow
source .venv/bin/activate
export PYTHONPATH=$(pwd)
bash docker/launch_backend_service.sh

# 3. Start frontend (in another terminal)
cd ~/projects/ragflow/web
npm run dev
```

### Check Service Status

```bash
# Infrastructure services
sudo systemctl status mysql redis-server minio elasticsearch

# RAGFlow processes
ps aux | grep -E "ragflow_server|task_executor"

# Ports
lsof -i:9380  # Backend
lsof -i:9222  # Frontend
```

### View Logs

```bash
# Real-time backend logs
tail -f ~/projects/ragflow/logs/ragflow_server.log
tail -f ~/projects/ragflow/logs/task_executor_0.log

# Real-time frontend logs (if using automated script)
tail -f /tmp/ragflow_frontend.log

# Infrastructure logs
sudo journalctl -u mysql -f
sudo journalctl -u redis-server -f
sudo journalctl -u elasticsearch -f
```

### GPU Monitoring

```bash
# Check GPU usage
nvidia-smi

# Watch GPU usage in real-time
watch -n 1 nvidia-smi

# Check processes using GPU
nvidia-smi pmon
```

## Service Endpoints

| Service       | URL/Connection                           |
|---------------|------------------------------------------|
| Frontend      | http://localhost:9222                    |
| Backend API   | http://127.0.0.1:9380                    |
| MySQL         | 127.0.0.1:5455 (root/infini_rag_flow)   |
| Redis         | 127.0.0.1:6379 (infini_rag_flow)        |
| MinIO API     | http://127.0.0.1:9000                    |
| MinIO Console | http://127.0.0.1:9001                    |
| Elasticsearch | http://127.0.0.1:1200 (elastic/infini_rag_flow) |

## Troubleshooting

### Backend won't start

```bash
# Check infrastructure
sudo systemctl status mysql redis-server minio elasticsearch

# Check configuration
cat ~/projects/ragflow/conf/service_conf.yaml

# Check logs
tail -100 ~/projects/ragflow/logs/ragflow_server.log
```

### Port already in use

```bash
# Find and kill process on port 9380 (backend)
lsof -ti:9380 | xargs kill -9

# Find and kill process on port 9222 (frontend)
lsof -ti:9222 | xargs kill -9
```

### Redis errors

```bash
# Check Redis status
sudo journalctl -u redis-server -n 50

# Restart Redis
sudo systemctl restart redis-server

# Test connection
redis-cli -a infini_rag_flow ping
```

### GPU not detected

```bash
# Check NVIDIA driver
nvidia-smi

# Test PyTorch CUDA
source .venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"

# Check ONNX Runtime providers
python -c "import onnxruntime as ort; print(ort.get_available_providers())"
```

### Conda interference

```bash
# Check if conda is active
echo $CONDA_DEFAULT_ENV

# Deactivate conda
conda deactivate

# Then activate uv venv
source .venv/bin/activate

# Verify correct python
which python  # Should show .venv/bin/python
```

## Maintenance

### Update dependencies

```bash
cd ~/projects/ragflow
source .venv/bin/activate
uv sync --all-extras
```

### Download new models

```bash
cd ~/projects/ragflow
source .venv/bin/activate
python download_deps.py
```

### Reset Elasticsearch password

```bash
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i
# Enter: infini_rag_flow
```

### Clear Redis cache

```bash
redis-cli -a infini_rag_flow FLUSHDB
```

### Clean logs

```bash
cd ~/projects/ragflow
rm -f logs/*.log logs/*.log.*
```

## Files & Directories

| Path | Description |
|------|-------------|
| `~/projects/ragflow/` | Project root |
| `~/projects/ragflow/.venv/` | Python virtual environment |
| `~/projects/ragflow/conf/service_conf.yaml` | Service configuration |
| `~/projects/ragflow/logs/` | Application logs |
| `~/projects/ragflow/web/` | Frontend source code |
| `~/projects/ragflow/api/` | Backend API source |
| `~/projects/ragflow/rag/` | RAG engine core |
| `/var/lib/mysql/` | MySQL data directory |
| `/var/lib/redis/` | Redis data directory |
| `/mnt/minio/data/` | MinIO data directory |
| `/var/lib/elasticsearch/` | Elasticsearch data |

## Useful Commands

### Database operations

```bash
# Connect to MySQL
mysql -u root -pinfini_rag_flow -h 127.0.0.1 -P 5455 rag_flow

# List tables
mysql -u root -pinfini_rag_flow -h 127.0.0.1 -P 5455 rag_flow -e "SHOW TABLES"

# Check Redis keys
redis-cli -a infini_rag_flow KEYS '*'

# Check Elasticsearch indices
curl -s -u elastic:infini_rag_flow http://127.0.0.1:1200/_cat/indices
```

### Performance monitoring

```bash
# CPU and memory usage
htop

# GPU monitoring
nvidia-smi dmon

# Network connections
netstat -tuln | grep -E "9380|9222|5455|6379|9000|1200"

# Disk usage
df -h
du -sh ~/projects/ragflow/
```

## Environment Setup

### Required for startup

```bash
# Always deactivate conda first
conda deactivate

# Activate uv virtual environment
source ~/projects/ragflow/.venv/bin/activate

# Set PYTHONPATH for backend
export PYTHONPATH=~/projects/ragflow
```

## Common Workflows

### Complete restart

```bash
# Stop everything
bash ~/projects/ragflow/stop_ragflow.sh
# Answer 'y' to stop infrastructure

# Start everything
bash ~/projects/ragflow/start_ragflow.sh
```

### Restart just RAGFlow (keep infrastructure)

```bash
# Stop RAGFlow only
pkill -f ragflow_server.py
pkill -f task_executor.py
lsof -ti:9222 | xargs kill

# Start RAGFlow
bash ~/projects/ragflow/start_ragflow.sh
```

### Update code and restart

```bash
# Stop RAGFlow
bash ~/projects/ragflow/stop_ragflow.sh

# Pull latest code
cd ~/projects/ragflow
git pull

# Update dependencies
source .venv/bin/activate
uv sync --all-extras

# Restart
bash ~/projects/ragflow/start_ragflow.sh
```

## Notes

- **Always deactivate conda** before starting RAGFlow
- Backend and frontend run in background when using `start_ragflow.sh`
- Check logs if something isn't working: `logs/ragflow_server.log`
- GPU memory usage is normal (~2-3GB idle, up to 10GB during processing)
- First document upload will be slower as models initialize
