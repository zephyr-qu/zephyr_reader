#!/bin/bash
# Environment provisioning for H1 PoC
# No special provisioning needed — uses Python stdlib only

echo "H1 PoC: No special provisioning required. Python stdlib only."
echo "Python version: $(python3 --version 2>&1)"
echo "Host: $(hostname 2>/dev/null || echo 'unknown')"
echo "OS: $(uname -a 2>/dev/null || echo 'Windows')"
