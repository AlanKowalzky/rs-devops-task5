#!/bin/bash
# Skrypt user-data do automatycznej instalacji K3s i Helm na EC2 (Amazon Linux 2 lub Ubuntu)
# Możesz wkleić ten skrypt do pola 'User data' podczas tworzenia instancji EC2

set -e

LOGFILE=/var/log/userdata-helm-install.log
exec > >(tee -a $LOGFILE) 2>&1

echo "[user-data] Start instalacji K3s i Helm: $(date)"

# Aktualizacja systemu
echo "[user-data] Aktualizacja systemu..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ $ID == "amzn" ]]; then
        yum update -y && echo "[user-data] yum update OK" || echo "[user-data][BŁĄD] yum update NIEUDANY"
        yum install -y curl tar && echo "[user-data] yum install curl tar OK" || echo "[user-data][BŁĄD] yum install curl tar NIEUDANY"
    elif [[ $ID == "ubuntu" ]]; then
        apt-get update -y && echo "[user-data] apt-get update OK" || echo "[user-data][BŁĄD] apt-get update NIEUDANY"
        apt-get install -y curl tar && echo "[user-data] apt-get install curl tar OK" || echo "[user-data][BŁĄD] apt-get install curl tar NIEUDANY"
    fi
fi

# Ujednolicone sprawdzanie K3s
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

# Dodaj alias kubectl jeśli nie istnieje
if ! command -v kubectl &> /dev/null; then
    ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

# Konfiguracja kubeconfig dla użytkownika
echo "[user-data] Konfiguracja kubeconfig dla użytkownika..."
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  mkdir -p /home/ec2-user/.kube
  cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
  chown ec2-user:ec2-user /home/ec2-user/.kube/config
  export KUBECONFIG=/home/ec2-user/.kube/config
  echo "[user-data] Kubeconfig OK"
else
  echo "[user-data][BŁĄD] Plik /etc/rancher/k3s/k3s.yaml nie istnieje! K3s mógł nie zostać poprawnie zainstalowany."
  exit 12
fi

# Instalacja Helm
export PATH=$PATH:/usr/local/bin

echo "[user-data] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && echo "[user-data] Instalacja Helm OK" || { echo "[user-data][BŁĄD] Instalacja Helm NIEUDANA"; exit 13; }

if ! command -v helm &> /dev/null; then
  echo "[user-data][BŁĄD] Helm nie jest dostępny w PATH!"
  exit 14
fi

# Sprawdzanie statusu klastra
echo "[user-data] Sprawdzanie statusu klastra..."
kubectl get nodes || { echo "[user-data][BŁĄD] kubectl get nodes NIEUDANE"; exit 15; }

# --- Wymuszenie poprawnych uprawnień kubeconfig dla ec2-user ---
echo "[user-data] Wymuszam poprawne uprawnienia kubeconfig dla ec2-user..."
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
sudo chmod 600 /home/ec2-user/.kube/config
export KUBECONFIG=/home/ec2-user/.kube/config

# --- Automatyczna instalacja dashboardu K8s ---
echo "[user-data] Instaluję Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# --- Port-forward dashboardu na 8001 (w tle) ---
echo "[user-data] Uruchamiam port-forward dashboardu na 8001 (w tle)..."
nohup kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8001:443 > /home/ec2-user/dashboard-portforward.log 2>&1 &

# --- Instrukcja tunelowania SSH do dashboardu ---
echo "[user-data] Aby uzyskać dostęp do dashboardu na swoim komputerze, uruchom na swoim komputerze lokalnym:"
echo "ssh -i ~/.ssh/id_rsa -L 8001:localhost:8001 ec2-user@<PUBLICZNY_IP_EC2>"
echo "Następnie otwórz w przeglądarce: https://localhost:8001"

# --- Automatyczna instalacja Jenkins (NodePort 30080, persistence off) ---
echo "[user-data] Tworzę namespace jenkins (jeśli nie istnieje)..."
kubectl create namespace jenkins || true

echo "[user-data] Instaluję Jenkins przez Helm (NodePort 30080, persistence off)..."
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=30080 \
  --set persistence.enabled=false

# --- Port-forward Jenkins na 30080 (w tle) ---
echo "[user-data] Uruchamiam port-forward Jenkins na 30080 (w tle)..."
nohup kubectl -n jenkins port-forward svc/jenkins 30080:8080 > /home/ec2-user/jenkins-portforward.log 2>&1 &

echo "[user-data] Jenkins będzie dostępny na http://<PUBLICZNY_IP_EC2>:30080"

echo "[user-data] Gotowe! K3s i Helm są zainstalowane. Możesz wdrażać aplikacje na Kubernetes."
echo "Aby korzystać z kubectl bez sudo, użyj: export KUBECONFIG=/home/ec2-user/.kube/config" 