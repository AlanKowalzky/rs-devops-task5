#!/bin/bash
# Skrypt user-data do automatycznej instalacji K3s, Helm i Jenkins na EC2 (Amazon Linux 2 lub Ubuntu) – wersja task6
set -e

LOGFILE=/var/log/userdata-jenkins-install.log
exec > >(tee -a $LOGFILE) 2>&1

echo "[user-data] Start instalacji K3s, Helm i Jenkins: $(date)"

# Aktualizacja systemu
echo "[user-data] Aktualizacja systemu..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ $ID == "amzn" ]]; then
        yum update -y
        yum install -y curl tar
    elif [[ $ID == "ubuntu" ]]; then
        apt-get update -y
        apt-get install -y curl tar
    fi
fi

# Instalacja K3s
K3S_OK=0
if systemctl is-active --quiet k3s && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  if kubectl get nodes 2>/dev/null | grep -q ' Ready '; then
    echo "[user-data] K3s już działa i API odpowiada. Pomijam instalację."
    K3S_OK=1
  else
    echo "[user-data][BŁĄD] K3s działa, ale API nie odpowiada. Będzie reinstalacja."
  fi
else
  echo "[user-data][BŁĄD] K3s nie działa lub brak kubeconfig. Będzie reinstalacja."
fi
if [ $K3S_OK -eq 0 ]; then
  echo "[user-data] K3s nie działa lub API nie odpowiada – czyszczę pozostałości i instaluję od nowa..."
  /usr/local/bin/k3s-uninstall.sh || true
  rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/systemd/system/k3s*
  curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh - && echo "[user-data] Instalacja K3s OK" || { echo "[user-data][BŁĄD] Instalacja K3s NIEUDANA"; exit 10; }
  sleep 5
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  if ! kubectl get nodes 2>/dev/null | grep -q ' Ready '; then
    echo "[user-data][BŁĄD] K3s nadal nie działa po instalacji! Logi K3s:"
    journalctl -u k3s --no-pager | tail -30
    exit 11
  fi
fi

# --- Czekaj na pojawienie się i poprawność kubeconfig ---
echo "[user-data] Oczekiwanie na /etc/rancher/k3s/k3s.yaml..."
for i in {1..30}; do
  if [ -s /etc/rancher/k3s/k3s.yaml ] && grep -q "clusters:" /etc/rancher/k3s/k3s.yaml; then
    echo "[user-data] Plik kubeconfig znaleziony i wygląda OK."
    break
  else
    echo "[user-data] Brak lub niepoprawny kubeconfig, czekam 5s..."
    sleep 5
  fi
done

# --- Skopiuj kubeconfig i ustaw uprawnienia ---
sudo mkdir -p /home/ec2-user/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
sudo chmod 600 /home/ec2-user/.kube/config

# --- Nadaj prawa do certyfikatów (tylko DEV!) ---
sudo chmod -R a+r /var/lib/rancher/k3s/server/tls/

# --- Wymuś adres 127.0.0.1 w kubeconfig (naprawa TLS) ---
sudo sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|g' /home/ec2-user/.kube/config

# --- Ustaw KUBECONFIG globalnie i dla wszystkich typów sesji ---
echo 'export KUBECONFIG=/home/ec2-user/.kube/config' | sudo tee /etc/profile.d/kubeconfig.sh
echo 'export KUBECONFIG=/home/ec2-user/.kube/config' >> /home/ec2-user/.bashrc
echo 'export KUBECONFIG=/home/ec2-user/.kube/config' >> /home/ec2-user/.bash_profile
sudo chmod 755 /etc/profile.d/kubeconfig.sh

# Instalacja Helm
export PATH=$PATH:/usr/local/bin

echo "[user-data] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

if ! command -v helm &> /dev/null; then
  echo "[user-data][BŁĄD] Helm nie jest dostępny w PATH!"
  exit 14
fi

# Sprawdzanie statusu klastra
echo "[user-data] Sprawdzanie statusu klastra..."
kubectl get nodes || { echo "[user-data][BŁĄD] kubectl get nodes NIEUDANE"; exit 15; }

# Dodaj repozytorium Jenkins i zaktualizuj repozytoria przed instalacją
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# --- Automatyczna instalacja Jenkins (NodePort 30080, persistence ON, minimalny rozmiar) ---
echo "[user-data] Tworzę namespace jenkins (jeśli nie istnieje)..."
kubectl create namespace jenkins || true

echo "[user-data] Instaluję Jenkins przez Helm (NodePort 30080, persistence ON)..."
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=30080 \
  --set persistence.enabled=true \
  --set persistence.size=2Gi \
  --set persistence.storageClass=local-path \
  --set controller.resources.requests.cpu=50m \
  --set controller.resources.requests.memory=256Mi \
  --set controller.resources.limits.cpu=500m \
  --set controller.resources.limits.memory=1Gi

# --- Czekaj na uruchomienie podu Jenkins przed port-forward ---
echo "[user-data] Oczekiwanie na uruchomienie podu Jenkins..."
for i in {1..30}; do
  STATUS=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.phase}')
  if [ "$STATUS" = "Running" ]; then
    echo "[user-data] Jenkins pod jest Running."
    break
  else
    echo "[user-data] Jenkins pod status: $STATUS. Czekam 10s..."
    sleep 10
  fi
done

# --- Port-forward Jenkins na 30080 (w tle) ---
echo "[user-data] Uruchamiam port-forward Jenkins na 30080 (w tle)..."
nohup kubectl -n jenkins port-forward svc/jenkins 30080:8080 > /home/ec2-user/jenkins-portforward.log 2>&1 &

echo "[user-data] Jenkins będzie dostępny na http://<PUBLICZNY_IP_EC2>:30080 (persistence 2Gi)" 

# Skopiuj plik JCasC do katalogu Jenkins (jeśli istnieje w /home/ec2-user)
if [ -f /home/ec2-user/jenkins-casc-task6.yaml ]; then
  mkdir -p /var/jenkins_home/casc_configs/
  cp /home/ec2-user/jenkins-casc-task6.yaml /var/jenkins_home/casc_configs/
  chown -R 1000:1000 /var/jenkins_home/casc_configs/
  echo "[user-data] Skopiowano jenkins-casc-task6.yaml do /var/jenkins_home/casc_configs/"
fi 