#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl apply -f /tmp/grafana-loki-setup.yaml

# restart grafana to pick provisioning
kubectl -n monitoring rollout restart deployment/grafana
kubectl -n monitoring rollout status deployment/grafana --timeout=120s
kubectl -n monitoring rollout status daemonset/promtail --timeout=120s || true

# generate traffic / logs
for i in 1 2 3 4 5; do
  curl -s http://127.0.0.1:30001/health >/dev/null || true
  curl -s http://127.0.0.1:30001/users/1 >/dev/null || true
  curl -s http://127.0.0.1:30002/health >/dev/null || true
  curl -s http://127.0.0.1:30002/orders/1 >/dev/null || true
  sleep 1
done

sleep 15

echo "=== PODS ==="
kubectl get pods -n monitoring

echo "=== LOKI LABELS ==="
curl -s http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels || \
  kubectl -n monitoring exec deploy/loki -- wget -qO- http://127.0.0.1:3100/loki/api/v1/labels || \
  curl -s http://127.0.0.1:3100/loki/api/v1/labels || true
echo

# query via port-forward style from a curl pod
kubectl -n monitoring run lokiq --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  curl -sG "http://loki:3100/loki/api/v1/label/namespace/values" || true
echo

echo "GRAFANA_LOKI_OK"
echo "Open: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):30300"
echo "Login: admin / devops-diploma"
echo "Dashboard: Dashboards -> DevOps Diploma -> Microservices Logs (Loki)"
echo "Explore: Explore -> Loki -> {namespace=\"microservices\"}"
