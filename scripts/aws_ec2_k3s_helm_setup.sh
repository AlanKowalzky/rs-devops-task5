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

# Sprawdź, czy K3s już działa
if systemctl is-active --quiet k3s; then
  echo "K3s już działa. Pomijam instalację."
else
  echo "K3s nie działa – czyszczę pozostałości i instaluję od nowa..."
  sudo /usr/local/bin/k3s-uninstall.sh || true
  sudo rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/systemd/system/k3s*
  curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -
fi

# Dodaj alias kubectl jeśli nie istnieje
if ! command -v kubectl &> /dev/null; then
    sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

# Konfiguracja kubeconfig dla użytkownika
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  echo "[2.5/3] Konfiguracja kubeconfig dla użytkownika..."
  mkdir -p $HOME/.kube
  sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  export KUBECONFIG=$HOME/.kube/config
else
  echo "[BŁĄD] Plik /etc/rancher/k3s/k3s.yaml nie istnieje! K3s mógł nie zostać poprawnie zainstalowany."
fi

echo "[2/3] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[3/3] Sprawdzanie statusu klastra..."
kubectl get nodes

echo "\nGotowe! K3s i Helm są zainstalowane. Możesz wdrażać aplikacje na Kubernetes."
echo "Aby korzystać z kubectl bez sudo, użyj: export KUBECONFIG=\$HOME/.kube/config" 