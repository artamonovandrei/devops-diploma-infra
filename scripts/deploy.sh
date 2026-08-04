#!/bin/bash
# Wdrożenie całego projektu od zera (Terraform → Ansible → app → monitoring).
# Wymaga: aws, terraform, ansible, ssh, curl, klucz ~/.ssh/devops-diploma
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops-diploma}"
INVENTORY="$ROOT_DIR/ansible/inventory/hosts"
INVENTORY_EXAMPLE="$ROOT_DIR/ansible/inventory/hosts.example"

echo "=== DevOps Diploma - Deploy Script ==="

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: brak klucza SSH: $SSH_KEY" >&2
  exit 1
fi

# 1. Bootstrap S3 (idempotent)
echo "[1/6] Bootstrap Terraform state..."
cd "$ROOT_DIR/terraform/bootstrap"
terraform init -input=false
terraform apply -auto-approve

# 2. Infrastructure
echo "[2/6] Deploy AWS infrastructure..."
cd "$ROOT_DIR/terraform/environments/dev"
terraform init -input=false
terraform apply -auto-approve

JENKINS_IP=$(terraform output -raw jenkins_public_ip)
K3S_IP=$(terraform output -raw k3s_public_ip)
JENKINS_PRIV=$(terraform output -raw jenkins_private_ip)
K3S_PRIV=$(terraform output -raw k3s_private_ip)

echo "Jenkins: http://${JENKINS_IP}:8080"
echo "Game:    http://${K3S_IP}:30080"
echo "Prometheus: http://${K3S_IP}:30090"
echo "Grafana: http://${K3S_IP}:30300"

# 3. Inventory from example
echo "[3/6] Update Ansible inventory..."
if [[ ! -f "$INVENTORY_EXAMPLE" ]]; then
  echo "ERROR: brak $INVENTORY_EXAMPLE" >&2
  exit 1
fi
cp "$INVENTORY_EXAMPLE" "$INVENTORY"
# hosts.example używa placeholderów JENKINS_PUBLIC_IP / K3S_PUBLIC_IP
# oraz nazw hostów jenkins / k3s — dopasuj też stare aliasy jenkins_host
sed -i.bak \
  -e "s/JENKINS_PUBLIC_IP/${JENKINS_IP}/g" \
  -e "s/K3S_PUBLIC_IP/${K3S_IP}/g" \
  "$INVENTORY"
rm -f "${INVENTORY}.bak"

# 4. Ansible bootstrap
echo "[4/6] Ansible bootstrap (Jenkins + k3s + runtimes)..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory/hosts playbooks/site.yml

# 5. Kubeconfig na Jenkins + checkout infra na k3s + deploy app
echo "[5/6] Wire Jenkins kubeconfig and deploy WebStrike..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@${K3S_IP}" bash -s <<EOF
set -euo pipefail
sudo mkdir -p /opt/devops-diploma-infra
if [ ! -d /opt/devops-diploma-infra/.git ]; then
  sudo git clone --depth 1 https://github.com/artamonovandrei/devops-diploma-infra.git /opt/devops-diploma-infra
else
  sudo git -C /opt/devops-diploma-infra fetch --depth 1 origin main
  sudo git -C /opt/devops-diploma-infra reset --hard origin/main
fi
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo kubectl apply -f /opt/devops-diploma-infra/kubernetes/apps/
sudo kubectl rollout status deployment/backend -n webstrike --timeout=180s
sudo kubectl rollout status deployment/web -n webstrike --timeout=180s
EOF

# kubeconfig dla użytkownika jenkins (przez host Jenkins)
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@${K3S_IP}" \
  "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s.yaml.raw
# Zamień loopback na prywatne IP k3s (Jenkins łączy się w VPC)
sed -e "s/127.0.0.1/${K3S_PRIV}/g" -e "s/localhost/${K3S_PRIV}/g" /tmp/k3s.yaml.raw > /tmp/k3s.yaml.jenkins

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@${JENKINS_IP}" bash -s <<EOF
set -euo pipefail
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /dev/stdin /var/lib/jenkins/.kube/config <<'KUBE'
$(cat /tmp/k3s.yaml.jenkins)
KUBE
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config
EOF

# 6. Monitoring
echo "[6/6] Monitoring (Prometheus + Grafana + Loki + Promtail)..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory/hosts playbooks/monitoring.yml

echo "=== Health checks ==="
curl --fail --retry 5 --retry-delay 5 "http://${K3S_IP}:30080/api/health"
echo
curl --fail --retry 5 --retry-delay 3 "http://${K3S_IP}:30090/-/ready"
echo
curl --fail --retry 5 --retry-delay 3 "http://${K3S_IP}:30300/api/health" || \
  curl --fail --retry 3 "http://${K3S_IP}:30300/login"

echo
echo "=== Deploy complete ==="
echo "Jenkins UI (jednorazowo: pluginy + credentials github-token / dockerhub / ses-smtp):"
echo "  http://${JENKINS_IP}:8080"
echo "Gra:         http://${K3S_IP}:30080"
echo "Prometheus:  http://${K3S_IP}:30090/targets"
echo "Grafana:     http://${K3S_IP}:30300"
