#!/bin/sh

# --- Dynamic CPU Thread Detection ---

# WORKER is now an ENV variable, but we'll still set it dynamically if it was not passed in
# In Docker, $HOSTNAME is automatically set to the container ID if WORKER ENV isn't set.
# We will use the ENV variable $WORKER if it's set, otherwise fall back to $HOSTNAME.
if [ -z "$WORKER" ]; then
    WORKER="$HOSTNAME"
fi

# Detect CPU threads and leave 2 free for the system
TOTAL_PROCESSORS=$(grep -c '^processor' /proc/cpuinfo)
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

# --- Execute the Binary (aitraining_dual) ---
# All other parameters (ALGO, POOL, WALLET, GPU settings) are read from the environment.
exec ./aitraining_dual \
    --algorithm "$ALGO" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --password "$WORKER" \
    --cpu-threads "$CPU_THREADS" \
    --keepalive true \
    --disable-gpu-checks false \
    --gpu-id 0,1,2,3
