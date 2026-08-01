#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== PROMTAIL LOGS ==="
kubectl -n monitoring logs daemonset/promtail --tail=30 || true

echo "=== GENERATE TRAFFIC ==="
for i in 1 2 3 4 5 6 7 8; do
  curl -s "http://127.0.0.1:30001/users/1" >/dev/null || true
  curl -s "http://127.0.0.1:30002/orders/1" >/dev/null || true
done
sleep 12

START=$(( $(date +%s) - 900 ))000000000
END=$(date +%s)000000000

echo "=== LOKI LABELS ==="
kubectl -n monitoring run loki-labels --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  curl -s http://loki:3100/loki/api/v1/labels || true
echo

echo "=== LOKI QUERY microservices ==="
kubectl -n monitoring run loki-query --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  sh -c "curl -sG 'http://loki:3100/loki/api/v1/query_range' \
    --data-urlencode 'query={namespace=\"microservices\"}' \
    --data-urlencode 'limit=5' \
    --data-urlencode 'start=${START}' \
    --data-urlencode 'end=${END}'" || true
echo

echo VERIFY_DONE
