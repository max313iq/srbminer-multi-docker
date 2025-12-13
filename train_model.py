#!/usr/bin/env python3
"""
Deep Learning Model Training Script
Trains a ResNet-50 model on synthetic image classification dataset
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import time
import os
import sys
from datetime import datetime
import random

# Set random seeds for reproducibility
torch.manual_seed(42)
np.random.seed(42)
random.seed(42)

class SyntheticImageDataset(Dataset):
    """Generate synthetic image data for training"""
    def __init__(self, num_samples=10000, img_size=224, num_classes=1000):
        self.num_samples = num_samples
        self.img_size = img_size
        self.num_classes = num_classes
        
    def __len__(self):
        return self.num_samples
    
    def __getitem__(self, idx):
        # Generate random image (3 channels, 224x224)
        image = torch.randn(3, self.img_size, self.img_size)
        label = random.randint(0, self.num_classes - 1)
        return image, label

class SimpleResNet(nn.Module):
    """Simplified ResNet-like architecture"""
    def __init__(self, num_classes=1000):
        super(SimpleResNet, self).__init__()
        self.conv1 = nn.Conv2d(3, 64, kernel_size=7, stride=2, padding=3)
        self.bn1 = nn.BatchNorm2d(64)
        self.relu = nn.ReLU(inplace=True)
        self.maxpool = nn.MaxPool2d(kernel_size=3, stride=2, padding=1)
        
        self.layer1 = self._make_layer(64, 128, 2)
        self.layer2 = self._make_layer(128, 256, 2)
        self.layer3 = self._make_layer(256, 512, 2)
        
        self.avgpool = nn.AdaptiveAvgPool2d((1, 1))
        self.fc = nn.Linear(512, num_classes)
        
    def _make_layer(self, in_channels, out_channels, num_blocks):
        layers = []
        layers.append(nn.Conv2d(in_channels, out_channels, kernel_size=3, stride=2, padding=1))
        layers.append(nn.BatchNorm2d(out_channels))
        layers.append(nn.ReLU(inplace=True))
        
        for _ in range(num_blocks - 1):
            layers.append(nn.Conv2d(out_channels, out_channels, kernel_size=3, padding=1))
            layers.append(nn.BatchNorm2d(out_channels))
            layers.append(nn.ReLU(inplace=True))
        
        return nn.Sequential(*layers)
    
    def forward(self, x):
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = self.maxpool(x)
        
        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        
        x = self.avgpool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)
        
        return x

def train_epoch(model, dataloader, criterion, optimizer, device, epoch, gpu_util_target=0.02):
    """Train for one epoch with minimal GPU/CPU utilization (uses <2% of resources)"""
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    
    for batch_idx, (inputs, targets) in enumerate(dataloader):
        inputs, targets = inputs.to(device), targets.to(device)
        
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
        _, predicted = outputs.max(1)
        total += targets.size(0)
        correct += predicted.eq(targets).sum().item()
        
        # Control GPU/CPU utilization by adding significant sleep
        # This keeps resource usage extremely low (<2%)
        time.sleep(2.0)
        
        if batch_idx % 10 == 0:
            accuracy = 100. * correct / total
            avg_loss = running_loss / (batch_idx + 1)
            print(f'Epoch: {epoch} | Batch: {batch_idx}/{len(dataloader)} | '
                  f'Loss: {avg_loss:.4f} | Acc: {accuracy:.2f}% ({correct}/{total})')
    
    epoch_loss = running_loss / len(dataloader)
    epoch_acc = 100. * correct / total
    
    return epoch_loss, epoch_acc

def save_checkpoint(model, optimizer, epoch, loss, accuracy, filepath):
    """Save model checkpoint"""
    checkpoint = {
        'epoch': epoch,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
        'loss': loss,
        'accuracy': accuracy,
        'timestamp': datetime.now().isoformat()
    }
    torch.save(checkpoint, filepath)
    print(f'✓ Checkpoint saved: {filepath}')

def main():
    print("=" * 80)
    print("PyTorch Deep Learning Training Pipeline")
    print("=" * 80)
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"PyTorch Version: {torch.__version__}")
    print(f"CUDA Available: {torch.cuda.is_available()}")
    
    if torch.cuda.is_available():
        print(f"CUDA Version: {torch.version.cuda}")
        print(f"GPU Device: {torch.cuda.get_device_name(0)}")
        print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
    
    print("=" * 80)
    
    # Configuration - minimal resource usage
    num_epochs = 1000
    batch_size = 4  # Very small batch size for minimal GPU usage
    learning_rate = 0.001
    num_classes = 1000
    checkpoint_interval = 50  # Save less frequently
    
    # Set device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"\nUsing device: {device}")
    
    # Create dataset and dataloader
    print("\nInitializing dataset...")
    train_dataset = SyntheticImageDataset(num_samples=500, num_classes=num_classes)
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, num_workers=1)
    print(f"Dataset size: {len(train_dataset)} samples")
    print(f"Batch size: {batch_size}")
    print(f"Number of batches: {len(train_loader)}")
    
    # Create model
    print("\nInitializing model...")
    model = SimpleResNet(num_classes=num_classes).to(device)
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Total parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")
    
    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    
    print("\n" + "=" * 80)
    print("Starting Training")
    print("=" * 80)
    
    # Training loop
    for epoch in range(1, num_epochs + 1):
        print(f"\n{'='*80}")
        print(f"Epoch {epoch}/{num_epochs}")
        print(f"{'='*80}")
        
        epoch_start_time = time.time()
        
        # Train
        train_loss, train_acc = train_epoch(
            model, train_loader, criterion, optimizer, device, epoch
        )
        
        epoch_time = time.time() - epoch_start_time
        
        # Print epoch summary
        print(f"\n{'='*80}")
        print(f"Epoch {epoch} Summary:")
        print(f"  Training Loss: {train_loss:.4f}")
        print(f"  Training Accuracy: {train_acc:.2f}%")
        print(f"  Epoch Time: {epoch_time:.2f}s")
        print(f"  Learning Rate: {learning_rate}")
        
        if torch.cuda.is_available():
            print(f"  GPU Memory Allocated: {torch.cuda.memory_allocated(0) / 1024**2:.2f} MB")
            print(f"  GPU Memory Cached: {torch.cuda.memory_reserved(0) / 1024**2:.2f} MB")
        
        print(f"{'='*80}")
        
        # Save checkpoint
        if epoch % checkpoint_interval == 0:
            checkpoint_path = f'/workspace/checkpoints/model_epoch_{epoch}.pth'
            os.makedirs('/workspace/checkpoints', exist_ok=True)
            save_checkpoint(model, optimizer, epoch, train_loss, train_acc, checkpoint_path)
        
        # Add significant delay between epochs to keep resource usage minimal
        time.sleep(10)
    
    print("\n" + "=" * 80)
    print("Training Complete!")
    print(f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nTraining interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n\nError during training: {e}")
        sys.exit(1)
