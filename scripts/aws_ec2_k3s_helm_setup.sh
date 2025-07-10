#!/bin/bash
# Skrypt do automatycznej instalacji K3s i Helm na EC2 (Amazon Linux 2 lub Ubuntu)
# Uruchom jako root lub z sudo

set -e

# Aktualizacja systemu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ $ID == "amzn" ]]; then
        sudo yum update -y
        sudo yum install -y curl tar
    elif [[ $ID == "ubuntu" ]]; then
        sudo apt-get update -y
        sudo apt-get install -y curl tar
    fi
fi

echo "[1/3] Instalacja K3s..."
curl -sfL https://get.k3s.io | sh -

# Dodaj alias kubectl jeśli nie istnieje
if ! command -v kubectl &> /dev/null; then
    sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

echo "[2/3] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[3/3] Sprawdzanie statusu klastra..."
sudo kubectl get nodes

echo "\nGotowe! K3s i Helm są zainstalowane. Możesz wdrażać aplikacje na Kubernetes." 