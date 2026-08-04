#!/bin/bash
# Jedyna rekomendowana ścieżka monitoringu (t3.small):
# Prometheus + node-exporter + kube-state-metrics + Grafana + Loki + Promtail + Alertmanager
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MON_DIR="${SCRIPT_DIR}/../kubernetes/monitoring"

if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
free -h

# Usuń ciężki Helm stack tylko jeśli istnieje (nie przy każdym apply)
if helm status kube-prometheus -n monitoring >/dev/null 2>&1; then
  echo "Removing heavy kube-prometheus-stack (replaced by lite manifests)..."
  helm uninstall kube-prometheus -n monitoring || true
fi
if helm status loki -n monitoring >/dev/null 2>&1; then
  helm uninstall loki -n monitoring || true
fi

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

apply_if_present() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "apply: $f"
    kubectl apply -f "$f"
  else
    echo "WARN: missing $f"
  fi
}

apply_if_present "${MON_DIR}/prometheus.yaml"
apply_if_present "${MON_DIR}/infra-metrics.yaml"
apply_if_present "${MON_DIR}/promtail.yaml"

# Grafana + Loki + Alertmanager (idempotent)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
type: Opaque
stringData:
  admin-user: admin
  admin-password: devops-diploma
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: true
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.monitoring.svc.cluster.local:3100
        editable: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels: { app: grafana }
  template:
    metadata:
      labels: { app: grafana }
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:11.1.0
          env:
            - name: GF_SECURITY_ADMIN_USER
              valueFrom:
                secretKeyRef: { name: grafana-admin, key: admin-user }
            - name: GF_SECURITY_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef: { name: grafana-admin, key: admin-password }
            - name: GF_PATHS_PROVISIONING
              value: /etc/grafana/provisioning
          ports: [{ containerPort: 3000 }]
          resources:
            requests: { memory: "64Mi", cpu: "50m" }
            limits: { memory: "192Mi", cpu: "200m" }
          volumeMounts:
            - { name: datasources, mountPath: /etc/grafana/provisioning/datasources }
      volumes:
        - name: datasources
          configMap: { name: grafana-datasources }
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  selector: { app: grafana }
  ports: [{ port: 3000, targetPort: 3000, nodePort: 30300 }]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels: { app: loki }
  template:
    metadata:
      labels: { app: loki }
    spec:
      containers:
        - name: loki
          image: grafana/loki:2.9.8
          args: ["-config.file=/etc/loki/local-config.yaml"]
          ports: [{ containerPort: 3100 }]
          resources:
            requests: { memory: "64Mi", cpu: "50m" }
            limits: { memory: "192Mi", cpu: "200m" }
---
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: monitoring
spec:
  selector: { app: loki }
  ports: [{ port: 3100, targetPort: 3100 }]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    route:
      receiver: default
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    receivers:
      - name: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels: { app: alertmanager }
  template:
    metadata:
      labels: { app: alertmanager }
    spec:
      containers:
        - name: alertmanager
          image: prom/alertmanager:v0.27.0
          args:
            - --config.file=/etc/alertmanager/alertmanager.yml
          ports: [{ containerPort: 9093 }]
          resources:
            requests: { memory: "32Mi", cpu: "20m" }
            limits: { memory: "64Mi", cpu: "100m" }
          volumeMounts:
            - { name: config, mountPath: /etc/alertmanager }
      volumes:
        - name: config
          configMap: { name: alertmanager-config }
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector: { app: alertmanager }
  ports: [{ port: 9093, targetPort: 9093 }]
EOF

apply_if_present "${MON_DIR}/grafana-dashboard.yaml"

kubectl rollout status deployment/prometheus -n monitoring --timeout=180s || true
kubectl rollout status deployment/grafana -n monitoring --timeout=180s || true
kubectl rollout status deployment/kube-state-metrics -n monitoring --timeout=120s || true

kubectl get pods -n monitoring -o wide
kubectl get svc -n monitoring

PUB="$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo '<k3s-ip>')"
echo "MONITORING_OK"
echo "Prometheus: http://${PUB}:30090   (targets: webstrike-backend, node-exporter, kube-state-metrics)"
echo "Grafana:    http://${PUB}:30300   (admin / devops-diploma — Secret grafana-admin)"
echo "Demo query: up{job=\"webstrike-backend\"}   oraz   kube_pod_info{namespace=\"webstrike\"}"
