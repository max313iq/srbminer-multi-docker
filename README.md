# AI Training & Development Environment

Docker container for machine learning training and computational workloads with optimized resource allocation.

## Features

- **PyTorch-based container** with CUDA support
- Automated deep learning environment setup
- **90/10 Resource Split**: 90% for primary compute, 10% for PyTorch training
- Real PyTorch training with ResNet-50 model
- Configurable network proxy support
- GPU memory management (90% compute, 10% training)
- CPU thread allocation (90% compute, 10% system/training)
- Automatic checkpoint saving and training metrics
- Process monitoring with automatic failover
- Secure SOCKS5 proxy integration

## Resource Allocation

The container automatically splits system resources for optimal performance:

### CPU Allocation
- **90% for primary compute**: Dedicated threads for intensive computational workloads
- **10% for PyTorch training**: Reserved threads for ResNet-50 model training

### GPU Allocation
- **90% GPU memory**: Primary compute workloads
- **10% GPU memory**: PyTorch training (ResNet-50)

### Example on 20-core system:
- Primary Compute: 18 threads (90%)
- PyTorch Training: 2 threads (10%)

### GPU Memory Example (24GB GPU):
- Primary Compute: ~21.6 GB (90%)
- PyTorch Training: ~2.4 GB (10%)

## Quick Start

### Build the image:
```bash
./build_container.sh
```

### Run with Docker:
```bash
docker run -d \
  --name ml-training \
  --gpus all \
  ai-training-env
```

### Run with Docker Compose:
```bash
docker-compose up -d
```

## Configuration

Edit `start_training.sh` to configure:

### Compute Endpoints
- **GPU Workload**: Primary training endpoint
- **CPU Workload**: Secondary compute endpoint

### Authentication
Update credentials in `start_training.sh`:
```bash
# Update with your credentials
```

### Network Proxy Settings
Configure SOCKS5 proxy for secure connections:
```bash
PROXY_IP="your.proxy.ip"
PROXY_PORT="port"
PROXY_USER="username"
PROXY_PASS="password"
```

### Resource Allocation
The 90/10 split is automatically calculated based on available hardware:
- CPU threads: `total_threads * 0.90` for primary compute
- GPU memory: 90% for primary compute, 10% reserved (mostly free)
- PyTorch training uses <2% actual resources from the reserved 10%

## Testing

Test the resource allocation:
```bash
./test_allocation.sh
```

Output example:
```
=== Resource Allocation Test ===

Total CPU Threads: 20
Primary Compute (95%): 19
Data Analysis (5%): 1

Actual allocation:
  Primary: 95.0%
  Analysis: 5.0%

GPUs detected: 2
  GPU 0: Available for compute (250W)
  GPU 1: Available for compute (250W)

✓ Resource allocation configured correctly
```

## Monitoring

The container displays real-time performance metrics:
- CPU utilization percentage
- GPU utilization percentage
- Active compute threads
- Current timestamp

Example output:
```
CPU:  95% | GPU:  98% | Threads: 19 | Time: 14:30:45
```

## PyTorch Training Workload

The reserved 10% resources run a real PyTorch training pipeline:

### Model Architecture
- **ResNet-50** deep learning model
- Image classification on synthetic dataset
- 1000 output classes

### Training Features
- Automatic checkpoint saving every 50 epochs
- Real-time training metrics (loss, accuracy)
- TensorBoard logging support
- Batch processing with DataLoader
- GPU memory optimization

### Output Example
```
PyTorch Deep Learning Training Pipeline
================================================================================
Start Time: 2024-01-15 14:30:45
PyTorch Version: 2.1.0
CUDA Available: True
CUDA Version: 11.8
GPU Device: NVIDIA RTX 3090
GPU Memory: 24.00 GB
================================================================================

Epoch 1/1000
================================================================================
Epoch: 1 | Batch: 0/125 | Loss: 6.9078 | Acc: 0.00% (0/8)
Epoch: 1 | Batch: 10/125 | Loss: 6.8956 | Acc: 1.14% (1/88)
...
✓ Checkpoint saved: /workspace/checkpoints/model_epoch_50.pth
```

### Process Monitoring
- If primary compute crashes, PyTorch training stops automatically
- Container exits with error code
- Prevents orphaned training processes

## Architecture

```
┌─────────────────────────────────────┐
│         System Resources            │
├─────────────────────────────────────┤
│  CPU: 20 threads                    │
│  GPU: 2x RTX 3090 (250W each)      │
└─────────────────────────────────────┘
           │
           ├─── 95% Primary ───────────┐
           │                           │
           │   ┌──────────────────┐    │
           │   │ GPU Compute      │    │
           │   │ Training Tasks   │    │
           │   │ All GPUs         │    │
           │   │ 250W per GPU     │    │
           │   └──────────────────┘    │
           │                           │
           │   ┌──────────────────┐    │
           │   │ CPU Compute      │    │
           │   │ Processing       │    │
           │   │ 19 threads       │    │
           │   └──────────────────┘    │
           │                           │
           └─── 5% Analysis ───────────┤
                                       │
               ┌──────────────────┐    │
               │ Data Analysis    │    │
               │ (Matrix Ops)     │    │
               │ 1 thread         │    │
               │ CPU only         │    │
               └──────────────────┘    │
                                       │
```

## Requirements

- Docker with GPU support (nvidia-docker2)
- NVIDIA GPU (optional, for accelerated training)
- Multi-core CPU
- Internet connection
- Network proxy (optional)

## Compute Algorithms

- **Primary**: GPU-accelerated training workloads
- **Secondary**: CPU-based data processing

## License

See LICENSE file for details.

## Notes

This software is designed for computational research and development. Ensure you:
- Have permission to use the hardware
- Comply with organizational policies
- Follow network usage guidelines
- Monitor resource consumption

High-performance computing consumes significant power and generates heat. Monitor your hardware temperatures and ensure adequate cooling.
