#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Docker for local image builds
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo usermod -aG docker ubuntu || true
  sudo systemctl enable --now docker
fi

# App source
if [ ! -d /opt/python-microservices-app ]; then
  sudo git clone https://github.com/artamonovandrei/python-microservices-app.git /opt/python-microservices-app
else
  sudo git -C /opt/python-microservices-app pull || true
fi

cd /opt/python-microservices-app
sudo docker build -t artamonovandrei/user-service:latest ./user-service
sudo docker build -t artamonovandrei/order-service:latest ./order-service

# Import into k3s containerd
sudo docker save artamonovandrei/user-service:latest | sudo k3s ctr images import -
sudo docker save artamonovandrei/order-service:latest | sudo k3s ctr images import -

# Refresh infra manifests
if [ -d /opt/devops-diploma-infra ]; then
  sudo git -C /opt/devops-diploma-infra pull || true
fi

sudo kubectl apply -f /opt/devops-diploma-infra/kubernetes/apps/
sudo kubectl -n microservices rollout restart deployment/user-service deployment/order-service
sudo kubectl -n microservices rollout status deployment/user-service --timeout=120s
sudo kubectl -n microservices rollout status deployment/order-service --timeout=120s
sudo kubectl get pods -n microservices
echo "APP_OK"
