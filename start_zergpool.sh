print_usage() {
    # Get CPU usage using simpler method
    local cpu_usage=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print int(0.5 + (($2+$4) - u1) * 100 / (t - t1)); }' <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat))
    
    # Get GPU usage
    local gpu_usage=0
    local gpu_count=0
    
    if command -v nvidia-smi &> /dev/null; then
        # Alternative method for GPU usage
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader | grep -o '[0-9]*' | head -1)
        gpu_count=1
        
        if [ -n "$gpu_usage" ] && [ "$gpu_usage" -ge 0 ] && [ "$gpu_usage" -le 100 ]; then
            printf "\rCPU: %3d%% | GPU: %3d%% | Threads: %2d | Time: %s" "$cpu_usage" "$gpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
        else
            printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
        fi
    else
        printf "\rCPU: %3d%% | GPU: N/A  | Threads: %2d | Time: %s" "$cpu_usage" "$CPU_THREADS" "$(date +%H:%M:%S)"
    fi
}
