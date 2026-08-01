#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl -n microservices patch svc user-service --type=merge -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":8001,"targetPort":8001,"nodePort":30001}]}}'
kubectl -n microservices patch svc order-service --type=merge -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":8002,"targetPort":8002,"nodePort":30002}]}}'
ufw allow 30001/tcp >/dev/null || true
ufw allow 30002/tcp >/dev/null || true

sleep 2
echo "=== USER HEALTH ==="
curl -s http://127.0.0.1:30001/health; echo
echo "=== ORDER HEALTH ==="
curl -s http://127.0.0.1:30002/health; echo
echo "=== USER 1 ==="
curl -s http://127.0.0.1:30001/users/1; echo
echo "=== ORDER 1 (enriched) ==="
curl -s http://127.0.0.1:30002/orders/1; echo
echo "=== CREATE ORDER ==="
curl -s -X POST http://127.0.0.1:30002/orders \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"product":"Monitor","quantity":1,"total":300}'; echo
echo "=== INACTIVE USER (expect 400) ==="
code=$(curl -s -o /tmp/out -w '%{http_code}' -X POST http://127.0.0.1:30002/orders \
  -H 'Content-Type: application/json' \
  -d '{"user_id":3,"product":"X","quantity":1,"total":10}')
echo "HTTP $code"; cat /tmp/out; echo
echo "=== PODS ==="
kubectl get pods -n microservices
echo TEST_OK
