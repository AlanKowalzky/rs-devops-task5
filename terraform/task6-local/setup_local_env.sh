#!/bin/bash
set -e

# Wybór narzędzia do klastra
if command -v minikube &> /dev/null; then
  echo "[INFO] Uruchamiam minikube..."
  minikube start --driver=docker
elif command -v k3d &> /dev/null; then
  echo "[INFO] Uruchamiam k3d..."
  k3d cluster create jenkins-local --agents 1 || true
elif command -v kind &> /dev/null; then
  echo "[INFO] Uruchamiam kind..."
  kind create cluster --name jenkins-local || true
else
  echo "[ERROR] Zainstaluj minikube, k3d lub kind!"
  exit 1
fi

# Instalacja Helm jeśli brak
if ! command -v helm &> /dev/null; then
  echo "[INFO] Instaluję Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Instalacja Jenkins przez Helm
kubectl create namespace jenkins || true
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm upgrade --install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --values jenkins-values.yaml

# Czekaj na gotowość Jenkins
kubectl rollout status deployment/jenkins -n jenkins --timeout=180s || true

# Pobierz hasło admina
echo "[INFO] Hasło administratora Jenkins:"
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- cat /run/secrets/chart-admin-password || true

# Port-forward Jenkins
nohup kubectl port-forward --namespace jenkins svc/jenkins 8080:8080 &

# Deploy aplikacji przez Helm
helm upgrade --install flask-app ../helm/flask-app -n default --values app-values.yaml

# Port-forward aplikacji
nohup kubectl port-forward svc/flask-app 5000:8080 &

sleep 5

cat <<EOF

---
Jenkins dostępny na: http://localhost:8080
Aplikacja dostępna na: http://localhost:5000
---
EOF 