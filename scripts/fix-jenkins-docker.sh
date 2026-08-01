#!/bin/bash
set -euo pipefail

# Docker access for Jenkins
sudo usermod -aG docker jenkins
sudo chmod 666 /var/run/docker.sock || true

# kubectl for Jenkins
if [ ! -f /usr/local/bin/kubectl ]; then
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/v1.31.2/bin/linux/amd64/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

# kubeconfig from k3s host (passed via stdin or existing file)
sudo mkdir -p /var/lib/jenkins/.kube
if [ -f /tmp/k3s.yaml ]; then
  sudo cp /tmp/k3s.yaml /var/lib/jenkins/.kube/config
fi
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config

# Fix server URL in kubeconfig to public IP of k3s
K3S_IP="${1:-18.197.236.46}"
sudo sed -i "s|https://127.0.0.1:6443|https://${K3S_IP}:6443|g" /var/lib/jenkins/.kube/config
sudo sed -i "s|https://localhost:6443|https://${K3S_IP}:6443|g" /var/lib/jenkins/.kube/config

# Clone infra manifests for deploy
if [ ! -d /opt/devops-diploma-infra ]; then
  sudo git clone https://github.com/artamonovandrei/devops-diploma-infra.git /opt/devops-diploma-infra
else
  sudo git -C /opt/devops-diploma-infra pull || true
fi
sudo chown -R jenkins:jenkins /opt/devops-diploma-infra

# pip/pytest for jenkins
sudo apt-get update -qq
sudo apt-get install -y -qq python3-pip python3-venv || true

sudo systemctl restart jenkins
sleep 15
sudo systemctl is-active jenkins

# Verify docker as jenkins
sudo -u jenkins docker ps >/dev/null && echo "DOCKER_OK"
sudo -u jenkins KUBECONFIG=/var/lib/jenkins/.kube/config kubectl get nodes && echo "KUBECTL_OK"
echo "JENKINS_DOCKER_FIXED"
