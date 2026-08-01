#!/bin/bash
# Skrypt wdrożenia całego projektu od zera
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== DevOps Diploma - Deploy Script ==="

# 1. Bootstrap S3 (if needed)
echo "[1/5] Bootstrap Terraform state..."
cd "$ROOT_DIR/terraform/bootstrap"
terraform init -input=false
terraform apply -auto-approve

# 2. Deploy infrastructure
echo "[2/5] Deploy AWS infrastructure..."
cd "$ROOT_DIR/terraform/environments/dev"
terraform init -input=false
terraform apply -auto-approve

JENKINS_IP=$(terraform output -raw jenkins_public_ip)
K3S_IP=$(terraform output -raw k3s_public_ip)

echo "Jenkins: http://${JENKINS_IP}:8080"
echo "k3s: http://${K3S_IP}"

# 3. Update Ansible inventory
echo "[3/5] Update Ansible inventory..."
INVENTORY="$ROOT_DIR/ansible/inventory/hosts"
sed -i "s/JENKINS_PUBLIC_IP/${JENKINS_IP}/g" "$INVENTORY" 2>/dev/null || \
  sed -i '' "s/JENKINS_PUBLIC_IP/${JENKINS_IP}/g" "$INVENTORY"
sed -i "s/K3S_PUBLIC_IP/${K3S_IP}/g" "$INVENTORY" 2>/dev/null || \
  sed -i '' "s/K3S_PUBLIC_IP/${K3S_IP}/g" "$INVENTORY"

# 4. Ansible bootstrap
echo "[4/5] Ansible bootstrap..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml

# 5. Deploy app
echo "[5/5] Deploy application to k3s..."
ssh -i ~/.ssh/devops-diploma ubuntu@"${K3S_IP}" \
  "sudo kubectl apply -f /opt/devops-diploma-infra/kubernetes/apps/ || \
   sudo kubectl apply -f -" < "$ROOT_DIR/kubernetes/apps/"*.yaml 2>/dev/null || true

echo "=== Deploy complete ==="
echo "Next: Configure Jenkins at http://${JENKINS_IP}:8080"
