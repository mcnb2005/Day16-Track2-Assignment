#!/bin/bash
set -euo pipefail
exec > >(tee /home/ubuntu/ml-benchmark/resource_usage.txt) 2>&1

echo "Lab 16 resource snapshot (UTC): $(date -u --iso-8601=seconds)"
echo
echo "=== CPU / processes ==="
top -b -n 1 -w 120 | sed -n '1,20p'
echo
echo "=== Memory ==="
free -h
echo
echo "=== Network interfaces ==="
ip -s link
