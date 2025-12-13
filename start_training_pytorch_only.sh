#!/bin/bash

# Set TERM variable and locale for consistent output
export TERM=xterm
export LC_ALL=C

echo "=== PyTorch Training Only Mode ==="
echo "This version skips the compute_engine workloads"
echo "and only runs PyTorch training"
echo "=========================================="

# Calculate CPU threads
TOTAL_THREADS=$(nproc --all)
echo "Total CPU Threads: $TOTAL_THREADS"

# Check GPU
GPU_COUNT=0
if command -v nvidia-smi &> /dev/null; then
    GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -1)
    if ! [[ "$GPU_COUNT" =~ ^[0-9]+$ ]]; then
        GPU_COUNT=0
    fi
fi

echo "GPUs detected: $GPU_COUNT"
echo "=========================================="

# Create logs directory
mkdir -p /workspace/logs

# Start PyTorch training
echo "Starting PyTorch model training..."
export OMP_NUM_THREADS=4

python3 /workspace/train_model.py 2>&1 | tee /workspace/logs/training.log
