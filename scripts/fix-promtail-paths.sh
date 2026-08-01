#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== POD LOG PATHS ==="
ls /var/log/pods | grep microservices || true
find /var/log/pods -path '*microservices*' -name '*.log' 2>/dev/null | head -20

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    positions:
      filename: /run/promtail/positions.yaml
    clients:
      - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push
    scrape_configs:
      - job_name: microservices-pods
        static_configs:
          - targets: [localhost]
            labels:
              job: microservices
              namespace: microservices
              __path__: /var/log/pods/microservices_*/*/*.log
        pipeline_stages:
          - cri: {}
          - regex:
              source: filename
              expression: '/var/log/pods/microservices_(?P<pod>.+)_[0-9a-f-]{36}/(?P<container>[^/]+)/'
          - labels:
              pod:
              container:
EOF

kubectl -n monitoring delete pod -l app=promtail --force --grace-period=0 2>/dev/null || true
kubectl -n monitoring rollout status daemonset/promtail --timeout=90s

for i in $(seq 1 15); do
  curl -s http://127.0.0.1:30001/users/1 >/dev/null || true
  curl -s http://127.0.0.1:30002/orders/1 >/dev/null || true
done
sleep 20

echo "=== PROMTAIL ==="
kubectl -n monitoring logs -l app=promtail --tail=40

START=$(( $(date +%s) - 1800 ))000000000
END=$(date +%s)000000000

echo "=== LABELS ==="
kubectl -n monitoring run loki-l --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  curl -s http://loki:3100/loki/api/v1/labels; echo

echo "=== QUERY ==="
kubectl -n monitoring run loki-q --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  sh -c "curl -sG 'http://loki:3100/loki/api/v1/query_range' \
    --data-urlencode 'query={job=\"microservices\"}' \
    --data-urlencode 'limit=5' \
    --data-urlencode 'start=${START}' \
    --data-urlencode 'end=${END}'"; echo
