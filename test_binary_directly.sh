#!/bin/bash
echo "=== Testing compute_engine binary directly ==="
echo ""

# Test if binary exists
if [ ! -f /opt/bin/compute_engine ]; then
    echo "ERROR: Binary not found"
    exit 1
fi

echo "Binary found at /opt/bin/compute_engine"
echo ""

# Show file info
echo "File info:"
file /opt/bin/compute_engine
echo ""

# Show dependencies
echo "Library dependencies:"
ldd /opt/bin/compute_engine 2>&1
echo ""

# Try to run it
echo "Attempting to run binary with --help:"
/opt/bin/compute_engine --help 2>&1
echo ""
echo "Exit code: $?"
