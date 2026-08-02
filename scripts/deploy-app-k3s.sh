#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

kubectl apply -f "$ROOT/kubernetes/apps/"
kubectl -n webstrike rollout status deployment/backend --timeout=180s
kubectl -n webstrike rollout status deployment/web --timeout=180s
kubectl get pods -n webstrike -o wide
kubectl get svc -n webstrike
