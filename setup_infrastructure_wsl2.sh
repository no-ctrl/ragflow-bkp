#!/bin/bash
#
# RAGFlow Infrastructure Setup Script for WSL2
# This script installs and configures all required services locally
#

set -e

echo "=========================================="
echo "RAGFlow Infrastructure Setup for WSL2"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from docker/.env
MYSQL_PORT=5455
MYSQL_PASSWORD="infini_rag_flow"
REDIS_PORT=6379
REDIS_PASSWORD="infini_rag_flow"
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_USER="rag_flow"
MINIO_PASSWORD="infini_rag_flow"
ES_PORT=1200
ES_PASSWORD="infini_rag_flow"
ELASTIC_VERSION="8.11.3"

echo -e "${GREEN}Step 1: Updating package list${NC}"
sudo apt update

echo ""
echo -e "${GREEN}Step 2: Installing MySQL 8.0${NC}"
# Install MySQL non-interactively
sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

echo ""
echo -e "${GREEN}Step 3: Configuring MySQL${NC}"
# Start MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Set root password and create database
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';"
sudo mysql -u root -p${MYSQL_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS rag_flow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -u root -p${MYSQL_PASSWORD} -e "FLUSH PRIVILEGES;"

# Configure MySQL to listen on custom port
sudo bash -c "cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF

# RAGFlow Configuration
port = ${MYSQL_PORT}
max_connections = 1000
max_allowed_packet = 1073741824
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF"

sudo systemctl restart mysql

echo -e "${GREEN}MySQL installed and configured on port ${MYSQL_PORT}${NC}"

echo ""
echo -e "${GREEN}Step 4: Installing Redis${NC}"
sudo apt install -y redis-server

echo ""
echo -e "${GREEN}Step 5: Configuring Redis${NC}"
# Configure Redis
sudo bash -c "cat > /etc/redis/redis.conf <<EOF
bind 127.0.0.1
port ${REDIS_PORT}
requirepass ${REDIS_PASSWORD}
maxmemory 128mb
maxmemory-policy allkeys-lru
daemonize no
supervised systemd
EOF"

sudo systemctl restart redis-server
sudo systemctl enable redis-server

echo -e "${GREEN}Redis installed and configured on port ${REDIS_PORT}${NC}"

echo ""
echo -e "${GREEN}Step 6: Installing MinIO${NC}"
# Download MinIO binary
cd /tmp
wget -q https://dl.min.io/server/minio/release/linux-amd64/minio
sudo mv minio /usr/local/bin/
sudo chmod +x /usr/local/bin/minio

# Create MinIO user and directories
sudo useradd -r minio-user -s /sbin/nologin 2>/dev/null || true
sudo mkdir -p /mnt/minio/data
sudo chown -R minio-user:minio-user /mnt/minio

# Create MinIO systemd service
sudo bash -c "cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
Environment=\"MINIO_ROOT_USER=${MINIO_USER}\"
Environment=\"MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}\"
ExecStart=/usr/local/bin/minio server --console-address :${MINIO_CONSOLE_PORT} --address :${MINIO_PORT} /mnt/minio/data
Restart=always
LimitNOFILE=65536
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl start minio
sudo systemctl enable minio

echo -e "${GREEN}MinIO installed and configured on ports ${MINIO_PORT} (API) and ${MINIO_CONSOLE_PORT} (Console)${NC}"

echo ""
echo -e "${GREEN}Step 7: Installing Elasticsearch ${ELASTIC_VERSION}${NC}"
# Install prerequisites
sudo apt install -y apt-transport-https

# Download and install Elasticsearch
cd /tmp
wget -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}-amd64.deb
sudo dpkg -i elasticsearch-${ELASTIC_VERSION}-amd64.deb || sudo apt --fix-broken install -y

# Configure Elasticsearch
sudo bash -c "cat > /etc/elasticsearch/elasticsearch.yml <<EOF
cluster.name: ragflow-cluster
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: ${ES_PORT}
discovery.type: single-node
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
cluster.routing.allocation.disk.watermark.low: 5gb
cluster.routing.allocation.disk.watermark.high: 3gb
cluster.routing.allocation.disk.watermark.flood_stage: 2gb
EOF"

# Configure JVM heap size (adjust based on available memory)
sudo bash -c "cat > /etc/elasticsearch/jvm.options.d/heap.options <<EOF
-Xms2g
-Xmx2g
EOF"

# Start Elasticsearch
sudo systemctl daemon-reload
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Wait for Elasticsearch to start
echo "Waiting for Elasticsearch to start..."
sleep 20

# Set elastic user password
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s <<EOF
${ES_PASSWORD}
EOF

echo -e "${GREEN}Elasticsearch installed and configured on port ${ES_PORT}${NC}"

echo ""
echo -e "${GREEN}Step 8: Verifying all services${NC}"
echo ""

# Check MySQL
if sudo systemctl is-active --quiet mysql; then
    echo -e "${GREEN}✓ MySQL is running on port ${MYSQL_PORT}${NC}"
else
    echo -e "${RED}✗ MySQL is not running${NC}"
fi

# Check Redis
if sudo systemctl is-active --quiet redis-server; then
    echo -e "${GREEN}✓ Redis is running on port ${REDIS_PORT}${NC}"
else
    echo -e "${RED}✗ Redis is not running${NC}"
fi

# Check MinIO
if sudo systemctl is-active --quiet minio; then
    echo -e "${GREEN}✓ MinIO is running on ports ${MINIO_PORT}/${MINIO_CONSOLE_PORT}${NC}"
else
    echo -e "${RED}✗ MinIO is not running${NC}"
fi

# Check Elasticsearch
if sudo systemctl is-active --quiet elasticsearch; then
    echo -e "${GREEN}✓ Elasticsearch is running on port ${ES_PORT}${NC}"
else
    echo -e "${RED}✗ Elasticsearch is not running${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Service Details:"
echo "  MySQL:         127.0.0.1:${MYSQL_PORT} (user: root, password: ${MYSQL_PASSWORD})"
echo "  Redis:         127.0.0.1:${REDIS_PORT} (password: ${REDIS_PASSWORD})"
echo "  MinIO API:     127.0.0.1:${MINIO_PORT} (user: ${MINIO_USER}, password: ${MINIO_PASSWORD})"
echo "  MinIO Console: http://127.0.0.1:${MINIO_CONSOLE_PORT}"
echo "  Elasticsearch: http://127.0.0.1:${ES_PORT} (user: elastic, password: ${ES_PASSWORD})"
echo ""
echo "Next steps:"
echo "  1. Verify GPU PyTorch installation"
echo "  2. Start RAGFlow backend services"
echo "  3. Start RAGFlow frontend"
echo ""
