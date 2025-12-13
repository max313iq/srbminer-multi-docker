#!/bin/bash

echo "=== Debugging compute_engine binary ==="
echo ""

# Check if binary exists
if [ ! -f /opt/bin/compute_engine ]; then
    echo "ERROR: Binary not found at /opt/bin/compute_engine"
    exit 1
fi

echo "✓ Binary exists"
echo ""

# Check file info
echo "File info:"
file /opt/bin/compute_engine
echo ""

# Check size
echo "File size:"
ls -lh /opt/bin/compute_engine
echo ""

# Check if executable
if [ -x /opt/bin/compute_engine ]; then
    echo "✓ Binary is executable"
else
    echo "ERROR: Binary is not executable"
    exit 1
fi
echo ""

# Check dependencies
echo "Checking library dependencies:"
ldd /opt/bin/compute_engine 2>&1 | head -30
echo ""

# Try to run with --help
echo "Attempting to run with --help:"
timeout 3 /opt/bin/compute_engine --help 2>&1 || echo "Exit code: $?"
echo ""

# Try to run with --version
echo "Attempting to run with --version:"
timeout 3 /opt/bin/compute_engine --version 2>&1 || echo "Exit code: $?"
echo ""

# Try to run with no args
echo "Attempting to run with no arguments:"
timeout 3 /opt/bin/compute_engine 2>&1 | head -20 || echo "Exit code: $?"
echo ""

# Check what happens when we try to start it
echo "Attempting minimal start (will timeout after 3 seconds):"
timeout 3 /opt/bin/compute_engine --algorithm kawpow --pool stratum+ssl://51.89.99.172:16161 --wallet test --password x --disable-gpu --disable-cpu 2>&1 | head -30
echo "Exit code: $?"
