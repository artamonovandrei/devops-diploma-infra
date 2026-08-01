#!/bin/bash
set -euo pipefail
CFG=/var/lib/jenkins/.kube/config
sudo sed -i 's#https://18.197.236.46:6443#https://10.0.1.119:6443#g' "$CFG"
sudo sed -i 's#https://127.0.0.1:6443#https://10.0.1.119:6443#g' "$CFG"
sudo sed -i 's#https://localhost:6443#https://10.0.1.119:6443#g' "$CFG"
sudo grep server "$CFG"
sudo -u jenkins KUBECONFIG="$CFG" kubectl get nodes --request-timeout=20s
sudo -u jenkins docker ps >/dev/null
echo ALL_OK
