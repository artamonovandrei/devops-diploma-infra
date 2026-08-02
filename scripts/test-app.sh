#!/usr/bin/env bash
set -euo pipefail

ufw allow 30080/tcp >/dev/null || true

echo "=== pods ==="
kubectl get pods -n webstrike -o wide

echo "=== healthz ==="
curl -sS http://127.0.0.1:30080/healthz; echo

echo "=== api health ==="
curl -sS http://127.0.0.1:30080/api/health; echo
