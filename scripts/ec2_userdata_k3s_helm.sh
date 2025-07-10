#!/bin/bash
# Skrypt user-data do automatycznej instalacji K3s i Helm na EC2 (Amazon Linux 2 lub Ubuntu)
# Możesz wkleić ten skrypt do pola 'User data' podczas tworzenia instancji EC2

set -e

# Aktualizacja systemu
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

echo "[1/3] Instalacja K3s..."
curl -sfL https://get.k3s.io | sh -

# Dodaj alias kubectl jeśli nie istnieje
if ! command -v kubectl &> /dev/null; then
    ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

echo "[2/3] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[3/3] Sprawdzanie statusu klastra..."
kubectl get nodes

echo "\nGotowe! K3s i Helm są zainstalowane. Możesz wdrażać aplikacje na Kubernetes." 