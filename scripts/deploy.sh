#!/bin/bash
# Wdrożenie od zera z ZACHOWANIEM Jenkins (EBS).
# Domyslnie reuse vol z .secrets / tfvars.
# Pierwszy bootstrap (nowy pusty dysk): ALLOW_NEW_JENKINS_VOLUME=1 ./scripts/deploy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops-diploma}"
INVENTORY="$ROOT_DIR/ansible/inventory/hosts"
INVENTORY_EXAMPLE="$ROOT_DIR/ansible/inventory/hosts.example"
TFVARS="$ROOT_DIR/terraform/environments/dev/terraform.tfvars"
SECRETS_DIR="$ROOT_DIR/.secrets"
VOLUME_FILE="$SECRETS_DIR/jenkins-home-volume-id.txt"
ALLOW_NEW_JENKINS_VOLUME="${ALLOW_NEW_JENKINS_VOLUME:-0}"

echo "=== DevOps Diploma - Deploy (Jenkins EBS safe) ==="

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: brak klucza SSH: $SSH_KEY" >&2
  exit 1
fi
if [[ ! -f "$TFVARS" ]]; then
  echo "ERROR: brak $TFVARS — skopiuj terraform.tfvars.example" >&2
  exit 1
fi

read_vol_file() {
  [[ -f "$VOLUME_FILE" ]] || { echo ""; return; }
  local v
  v="$(tr -d '[:space:]' < "$VOLUME_FILE")"
  [[ "$v" =~ ^vol-[0-9a-f]+$ ]] && echo "$v" || echo ""
}

read_vol_tfvars() {
  local v
  v="$(sed -n 's/^[[:space:]]*jenkins_home_volume_id[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$TFVARS" | head -1 | tr -d '[:space:]')"
  [[ "$v" =~ ^vol-[0-9a-f]+$ ]] && echo "$v" || echo ""
}

set_vol_tfvars() {
  local id="$1"
  if grep -qE '^[[:space:]]*jenkins_home_volume_id[[:space:]]*=' "$TFVARS"; then
    sed -i.bak -E "s|^[[:space:]]*jenkins_home_volume_id[[:space:]]*=[[:space:]]*\"[^\"]*\"|jenkins_home_volume_id = \"${id}\"|" "$TFVARS"
    rm -f "${TFVARS}.bak"
  else
    printf '\njenkins_home_volume_id = "%s"\n' "$id" >> "$TFVARS"
  fi
}

save_vol() {
  local id="$1"
  mkdir -p "$SECRETS_DIR"
  printf '%s' "$id" > "$VOLUME_FILE"
}

# --- Guard: nie tworz nowego pustego dysku bez zgody ---
VOL="$(read_vol_file)"
[[ -z "$VOL" ]] && VOL="$(read_vol_tfvars)"

if [[ -n "$VOL" ]]; then
  set_vol_tfvars "$VOL"
  save_vol "$VOL"
  echo "Jenkins EBS (reuse): $VOL — credentials/joby zostaną zachowane"
elif [[ "$ALLOW_NEW_JENKINS_VOLUME" == "1" ]]; then
  set_vol_tfvars ""
  echo "UWAGA: ALLOW_NEW_JENKINS_VOLUME=1 — pierwszy bootstrap (pusty dysk)"
else
  cat >&2 <<EOF
ERROR: brak jenkins_home_volume_id — terraform utworzyłby NOWY pusty dysk.

Ustaw jedno z:
  1. $VOLUME_FILE  (vol-xxxxxxxx)
  2. jenkins_home_volume_id w $TFVARS
  3. Pierwszy raz: ALLOW_NEW_JENKINS_VOLUME=1 $0
EOF
  exit 1
fi

# 1. Bootstrap S3
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
K3S_PRIV=$(terraform output -raw k3s_private_ip)
VOL_OUT=$(terraform output -raw jenkins_home_volume_id)
set_vol_tfvars "$VOL_OUT"
save_vol "$VOL_OUT"
echo "Zapisano Jenkins EBS: $VOL_OUT"

echo "Jenkins: http://${JENKINS_IP}:8080"
echo "Game:    http://${K3S_IP}:30080"

# 3. Inventory
echo "[3/6] Update Ansible inventory..."
cp "$INVENTORY_EXAMPLE" "$INVENTORY"
sed -i.bak \
  -e "s/JENKINS_PUBLIC_IP/${JENKINS_IP}/g" \
  -e "s/K3S_PUBLIC_IP/${K3S_IP}/g" \
  "$INVENTORY"
rm -f "${INVENTORY}.bak"

# 4. Ansible — montuje TEN SAM EBS pod /var/lib/jenkins
echo "[4/6] Ansible bootstrap (Jenkins + k3s + runtimes)..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory/hosts playbooks/site.yml

# 5. App + kubeconfig na Jenkins
echo "[5/6] Deploy app + wire Jenkins kubeconfig..."
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

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@${K3S_IP}" \
  "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s.yaml.raw
sed -e "s/127.0.0.1/${K3S_PRIV}/g" -e "s/localhost/${K3S_PRIV}/g" /tmp/k3s.yaml.raw > /tmp/k3s.yaml.jenkins

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@${JENKINS_IP}" bash -s <<EOF
set -euo pipefail
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /dev/stdin /var/lib/jenkins/.kube/config <<'KUBE'
$(cat /tmp/k3s.yaml.jenkins)
KUBE
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config
sudo -u jenkins kubectl --kubeconfig=/var/lib/jenkins/.kube/config get nodes
EOF

# 6. Monitoring
echo "[6/6] Monitoring (Prometheus + Grafana)..."
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
echo "=== Deploy complete (Jenkins EBS: $VOL_OUT) ==="
echo "Jenkins UI: http://${JENKINS_IP}:8080  (credentials/joby z dysku — bez setup wizard)"
echo "Gra:        http://${K3S_IP}:30080"
echo "Prometheus: http://${K3S_IP}:30090/targets"
echo "Grafana:    http://${K3S_IP}:30300"
echo
echo "Jesli EBS mial juz konfiguracje — Multibranch/credentials sa na miejscu."
echo "Jesli pierwszy bootstrap — dodaj credentials + Multibranch raz w UI."
