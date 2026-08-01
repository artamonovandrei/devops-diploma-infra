#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/kube-prometheus-values.yaml \
  --wait --timeout 15m

# loki-stack may be deprecated; try it, fallback to loki + promtail
if ! helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  -f /tmp/loki-values.yaml \
  --wait --timeout 10m; then
  echo "loki-stack failed, trying grafana/loki + promtail"
  helm upgrade --install loki grafana/loki \
    --namespace monitoring \
    --set loki.commonConfig.replication_factor=1 \
    --set singleBinary.replicas=1 \
    --set singleBinary.resources.requests.memory=64Mi \
    --set gateway.enabled=false \
    --set test.enabled=false \
    --wait --timeout 10m || true
  helm upgrade --install promtail grafana/promtail \
    --namespace monitoring \
    --wait --timeout 5m || true
fi

kubectl get pods -n monitoring
echo "MONITORING_OK"
