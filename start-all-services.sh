#!/bin/bash

echo "Starting all RAGFlow services..."
echo ""
echo "NOTE: You need to add the following line to your /etc/hosts file:"
echo "127.0.0.1       es01 infinity mysql minio redis"
echo ""
echo "Press Enter to continue..."
read

# Start Elasticsearch
echo "Starting Elasticsearch..."
~/ragflow-services/start-elasticsearch.sh

# Start MySQL
echo "Starting MySQL..."
~/ragflow-services/start-mysql.sh

# Start Redis
echo "Starting Redis..."
~/ragflow-services/start-redis.sh

# Start MinIO
echo "Starting MinIO..."
~/ragflow-services/start-minio.sh

echo ""
echo "All services started!"
echo ""
echo "Service URLs:"
echo "- Elasticsearch: http://localhost:1200"
echo "- MySQL: localhost:5455"
echo "- Redis: localhost:6379"
echo "- MinIO API: http://localhost:9000"
echo "- MinIO Console: http://localhost:9001"
echo ""
echo "You can now start the RAGFlow backend and frontend"