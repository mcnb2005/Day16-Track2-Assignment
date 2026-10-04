#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for CPU LightGBM benchmark node"

apt-get update -y
apt-get install -y python3 python3-pip

# Keep package installation and the full dataset benchmark reliable on small lab VMs.
if ! swapon --show=NAME --noheadings | grep -q '^/swapfile$'; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

pip3 install --upgrade pip
pip3 install lightgbm scikit-learn pandas numpy kaggle

mkdir -p /home/ubuntu/ml-benchmark
echo '${benchmark_script_b64}' | base64 --decode > /home/ubuntu/ml-benchmark/benchmark.py
chmod 755 /home/ubuntu/ml-benchmark/benchmark.py
chown -R ubuntu:ubuntu /home/ubuntu/ml-benchmark

echo "CPU environment ready: dependencies and /home/ubuntu/ml-benchmark/benchmark.py installed."
