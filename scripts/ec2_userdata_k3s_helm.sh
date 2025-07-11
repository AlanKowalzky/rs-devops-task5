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
        yum update -y
        yum install -y curl tar
    elif [[ $ID == "ubuntu" ]]; then
        apt-get update -y
        apt-get install -y curl tar
    fi
fi

echo "[user-data] Instalacja K3s..."
curl -sfL https://get.k3s.io | sh - || { echo "[user-data] Błąd instalacji K3s"; exit 1; }

# Dodaj alias kubectl jeśli nie istnieje
if ! command -v kubectl &> /dev/null; then
    ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

echo "[user-data] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || { echo "[user-data] Błąd instalacji Helm"; exit 2; }

if command -v helm &> /dev/null; then
    echo "[user-data] Helm zainstalowany: $(helm version)"
else
    echo "[user-data] Helm NIE został zainstalowany!"
    exit 3
fi

echo "[user-data] Sprawdzanie statusu klastra..."
kubectl get nodes

echo "[user-data] Gotowe! K3s i Helm są zainstalowane. Możesz wdrażać aplikacje na Kubernetes." 