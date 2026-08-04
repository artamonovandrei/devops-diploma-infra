#!/bin/bash
# Prosty, stabilny monitoring: Prometheus + Grafana (jeden plik stack.yaml)
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STACK="${SCRIPT_DIR}/../kubernetes/monitoring/stack.yaml"

# Swap pomaga na t3.small
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Usuń ciężkie / stare rzeczy, które zjadają RAM
helm uninstall kube-prometheus -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall promtail -n monitoring 2>/dev/null || true
kubectl -n monitoring delete deploy loki alertmanager kube-state-metrics promtail \
  daemonset/node-exporter daemonset/promtail --ignore-not-found 2>/dev/null || true

if [ ! -f "$STACK" ]; then
  echo "ERROR: brak $STACK" >&2
  exit 1
fi

kubectl apply -f "$STACK"

echo "Czekam na Prometheus i Grafana..."
kubectl -n monitoring rollout status deployment/prometheus --timeout=180s
kubectl -n monitoring rollout status deployment/grafana --timeout=180s

kubectl -n monitoring get pods,svc
PUB="$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo '<k3s-ip>')"
echo "MONITORING_OK"
echo "Prometheus: http://${PUB}:30090/targets"
echo "Grafana:    http://${PUB}:30300  (admin / devops-diploma)"
echo "Query:      up{job=\"webstrike-backend\"}  |  webstrike_players"
