#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

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
kubectl delete deploy,svc,ds,cm -n monitoring --all --force --grace-period=0 2>/dev/null || true
sleep 3

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ['localhost:9090']
      - job_name: webstrike-backend
        metrics_path: /api/health
        static_configs:
          - targets: ['backend.webstrike.svc.cluster.local:8000']
      - job_name: alertmanager
        static_configs:
          - targets: ['alertmanager.monitoring.svc.cluster.local:9093']
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
            - --storage.tsdb.retention.time=1d
          ports: [{ containerPort: 9090 }]
          resources:
            requests: { memory: "128Mi", cpu: "50m" }
            limits: { memory: "256Mi", cpu: "300m" }
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
  selector: { app: prometheus }
  ports: [{ port: 9090, targetPort: 9090 }]
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
            - { name: GF_SECURITY_ADMIN_USER, value: admin }
            - { name: GF_SECURITY_ADMIN_PASSWORD, value: devops-diploma }
          ports: [{ containerPort: 3000 }]
          resources:
            requests: { memory: "64Mi", cpu: "50m" }
            limits: { memory: "128Mi", cpu: "200m" }
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

# wait for pods
for i in $(seq 1 30); do
  ready=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c Running || true)
  echo "Running pods in monitoring: $ready"
  [ "$ready" -ge 4 ] && break
  sleep 10
done

kubectl get pods -n monitoring
kubectl get pods -n webstrike
echo "MONITORING_OK"
echo "Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):30300  (admin / devops-diploma)"
