#!/bin/bash
# Lekki monitoring na t3.small: Prometheus + Grafana + Loki + Alertmanager
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MON_DIR="${SCRIPT_DIR}/../kubernetes/monitoring"

# Swap for small instance
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
free -h

pkill -f 'helm upgrade' 2>/dev/null || true
helm uninstall kube-prometheus -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall promtail -n monitoring 2>/dev/null || true

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Prometheus (manifest z repo)
if [ -f "${MON_DIR}/prometheus.yaml" ]; then
  kubectl apply -f "${MON_DIR}/prometheus.yaml"
else
  echo "WARN: ${MON_DIR}/prometheus.yaml missing — using embedded fallback"
  kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ['localhost:9090']
      - job_name: webstrike-backend
        metrics_path: /metrics
        static_configs:
          - targets: ['backend.webstrike.svc.cluster.local:8000']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels: { app: prometheus }
  template:
    metadata:
      labels: { app: prometheus }
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.54.1
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.retention.time=2d
          ports: [{ containerPort: 9090 }]
          resources:
            requests: { memory: "128Mi", cpu: "50m" }
            limits: { memory: "384Mi", cpu: "400m" }
          volumeMounts:
            - { name: config, mountPath: /etc/prometheus }
      volumes:
        - name: config
          configMap: { name: prometheus-config }
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  selector: { app: prometheus }
  ports: [{ port: 9090, targetPort: 9090, nodePort: 30090 }]
EOF
fi

kubectl apply -f - <<'EOF'
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
            - { name: GF_SECURITY_ADMIN_USER, value: admin }
            - { name: GF_SECURITY_ADMIN_PASSWORD, value: devops-diploma }
            - { name: GF_PATHS_PROVISIONING, value: /etc/grafana/provisioning }
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
          ports: [{ containerPort: 9093 }]
          resources:
            requests: { memory: "32Mi", cpu: "20m" }
            limits: { memory: "64Mi", cpu: "100m" }
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

if [ -f "${MON_DIR}/grafana-dashboard.yaml" ]; then
  kubectl apply -f "${MON_DIR}/grafana-dashboard.yaml" || true
fi

for i in $(seq 1 36); do
  ready=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c Running || true)
  echo "Running pods in monitoring: $ready"
  [ "$ready" -ge 3 ] && break
  sleep 5
done

kubectl rollout status deployment/prometheus -n monitoring --timeout=180s || true
kubectl get pods -n monitoring -o wide
kubectl get svc -n monitoring

PUB="$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo '<k3s-ip>')"
echo "MONITORING_OK"
echo "Prometheus: http://${PUB}:30090"
echo "Grafana:    http://${PUB}:30300  (admin / devops-diploma)"
echo "Targets:    http://${PUB}:30090/targets  (webstrike-backend → /metrics)"
