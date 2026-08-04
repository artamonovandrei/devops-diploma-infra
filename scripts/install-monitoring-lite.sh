#!/bin/bash
# Prometheus + Grafana + Alertmanager (e-mail SES → a.artamonov@wp.pl)
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK="${ROOT_DIR}/kubernetes/monitoring/stack.yaml"
SES_ENV_FILE="${SES_ENV_FILE:-$ROOT_DIR/.secrets/ses-smtp.env}"

# Swap pomaga na t3.small
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Usuń ciężkie / stare rzeczy (NIE kasuj alertmanager z naszego stacku po apply)
helm uninstall kube-prometheus -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall promtail -n monitoring 2>/dev/null || true
kubectl -n monitoring delete deploy loki kube-state-metrics promtail \
  daemonset/node-exporter daemonset/promtail --ignore-not-found 2>/dev/null || true

if [ ! -f "$STACK" ]; then
  echo "ERROR: brak $STACK" >&2
  exit 1
fi

# --- SES SMTP (nie commituj hasła) ---
if [ -f "$SES_ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$SES_ENV_FILE"
  set +a
  echo "SES: loaded $SES_ENV_FILE"
fi

SES_SMTP_USER="${SES_SMTP_USER:-}"
SES_SMTP_PASSWORD="${SES_SMTP_PASSWORD:-}"
SES_FROM="${SES_FROM:-artamonovandrei88@gmail.com}"
SES_TO="${SES_TO:-a.artamonov@wp.pl}"
SES_SMTP_HOST="${SES_SMTP_HOST:-email-smtp.eu-central-1.amazonaws.com}"
SES_SMTP_PORT="${SES_SMTP_PORT:-587}"

if [ -z "$SES_SMTP_USER" ] || [ -z "$SES_SMTP_PASSWORD" ]; then
  echo "ERROR: brak SES_SMTP_USER / SES_SMTP_PASSWORD" >&2
  echo "  Ustaw env albo plik: $SES_ENV_FILE" >&2
  exit 1
fi

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

AM_CFG="$(mktemp)"
trap 'rm -f "$AM_CFG"' EXIT
cat > "$AM_CFG" <<EOF
global:
  resolve_timeout: 5m
  smtp_smarthost: '${SES_SMTP_HOST}:${SES_SMTP_PORT}'
  smtp_from: '${SES_FROM}'
  smtp_auth_username: '${SES_SMTP_USER}'
  smtp_auth_password: '${SES_SMTP_PASSWORD}'
  smtp_require_tls: true
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: email-wp
  routes:
    - match:
        alertname: Watchdog
      receiver: email-wp
      group_wait: 10s
      repeat_interval: 24h
receivers:
  - name: email-wp
    email_configs:
      - to: '${SES_TO}'
        send_resolved: true
        headers:
          Subject: '[WebStrike Alert] {{ .GroupLabels.alertname }}'
inhibit_rules: []
EOF

kubectl -n monitoring create secret generic alertmanager-config \
  --from-file=alertmanager.yml="$AM_CFG" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Alertmanager Secret OK → to=${SES_TO} from=${SES_FROM}"

kubectl apply -f "$STACK"

echo "Czekam na Prometheus / Grafana / Alertmanager..."
kubectl -n monitoring rollout status deployment/prometheus --timeout=180s
kubectl -n monitoring rollout status deployment/grafana --timeout=180s
kubectl -n monitoring rollout status deployment/alertmanager --timeout=180s

# Reload prometheus jeśli już działał (nowe rules)
kubectl -n monitoring exec deploy/prometheus -- wget -qO- --post-data='' http://127.0.0.1:9090/-/reload 2>/dev/null || true

kubectl -n monitoring get pods,svc
PUB="$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo '<k3s-ip>')"
echo "MONITORING_OK"
echo "Prometheus:    http://${PUB}:30090/alerts"
echo "Alertmanager:  http://${PUB}:30903"
echo "Grafana:       http://${PUB}:30300  (admin / devops-diploma)"
echo "Alert e-mail:  ${SES_TO} (Watchdog + WebStrikeBackendDown)"
