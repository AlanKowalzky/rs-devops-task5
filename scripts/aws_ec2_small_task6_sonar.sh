#!/bin/bash
set -e
set -x
set -o pipefail

# --- Skrypt status owy do /etc/profile.d ---
cat <<'EOF' | sudo tee /etc/profile.d/status_services.sh > /dev/null
#!/bin/bash
function show_status() {
  echo -e "\n==== STAN USŁUG ===-"
  export PATH=$PATH:/usr/bin:/usr/local/bin

  systemctl is-active --quiet docker && echo "[STATUS] Docker: OK" || echo "[STATUS] Docker: ERROR"
  systemctl is-active --quiet k3s && echo "[STATUS] K3s: OK" || echo "[STATUS] K3s: ERROR"

  K3S_API_OUTPUT=$(kubectl --kubeconfig /home/ec2-user/.kube/config cluster-info 2>&1)
  if echo "$K3S_API_OUTPUT" | grep -q "Kubernetes control plane is running"; then
    echo "[STATUS] K3s API: OK"
  elif echo "$K3S_API_OUTPUT" | grep -q "refused"; then
    echo "[STATUS] K3s API: REFUSED"
  elif echo "$K3S_API_OUTPUT" | grep -q "Unauthorized"; then
    echo "[STATUS] K3S API: AUTH_ERR"
  elif [ -z "$K3S_API_OUTPUT" ]; then
    echo "[STATUS] K3s API: NO_RESP"
  else
    echo "[STATUS] K3s API: UNKNOWN"
  fi

  EC2_PUBLIC_IP_STATUS_FUNC=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "UNKNOWN_IP")
  if [ "$EC2_PUBLIC_IP_STATUS_FUNC" != "UNKNOWN_IP" ] && curl -s --max-time 5 http://${EC2_PUBLIC_IP_STATUS_FUNC}:30080/login > /dev/null; then
    echo "[STATUS] Jenkins: HTTP OK ${EC2_PUBLIC_IP_STATUS_FUNC}:30080"
  else
    JENKINS_POD=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
    echo "[STATUS] Jenkins: $JENKINS_POD (HTTP ERR ${EC2_PUBLIC_IP_STATUS_FUNC}:30080)"
  fi

  docker ps | grep -q sonarqube && echo "[STATUS] SonarQube: CONTAINER OK" || echo "[STATUS] SonarQube: CONT_ERR"
  ss -tuln | grep -q 9000 && echo "[STATUS] SonarQube: PORT 9000 OK" || echo "[STATUS] SonarQube: PORT_ERR"
  curl -s http://localhost:9000 > /dev/null && echo "[STATUS] SonarQube: HTTP OK" || echo "[STATUS] SonarQube: HTTP_ERR"
  echo "[USAGE] RAM: $(free -m | awk '/Mem:/ {print $3"/"$2"MB"}') | CPU: $(nproc) | DYSK: $(df -h / | awk 'NR==2 {print $3"/"$2}')"
}
if [ "$1" = "loop" ]; then
  while true; do clear; show_status; sleep 2; done
else
  show_status
fi
EOF
sudo chmod +x /etc/profile.d/status_services.sh
echo '/etc/profile.d/status_services.sh' >> /home/ec2-user/.bash_profile

# --- Logowanie ---
LOGFILE=/var/log/userdata-jenkins-install.log
exec > >(sudo tee -a $LOGFILE) 2>&1

# --- Funkcja generyczna do oczekiwania na warunek ---
function wait_for_condition() {
  local max_attempts=$1
  local sleep_interval=$2
  local check_command="$3"
  local wait_message="$4"
  local success_message="$5"
  local error_message="$6"
  local exit_code_on_error=$7
  local debug_logs_command="$8"

  echo "[INFO] $wait_message"
  for i in $(seq 1 $max_attempts); do
    percent=$((i*100/max_attempts))
    bar=$(printf '%0.s#' $(seq 1 $((percent/5)) ))
    
    if eval "$check_command"; then
      echo "[READY] $success_message po $((i*sleep_interval))s [$percent%%] [$bar]"
      return 0
    fi

    echo -ne "[WAIT] $wait_message ($i/$max_attempts) [$percent%%] [$bar]\r"
    
    if [ -n "$debug_logs_command" ]; then
      echo "--- Logi debugowania ---"
      eval "$debug_logs_command" || true
      echo "------------------------"
    fi

    sleep "$sleep_interval"
    if [ $i -eq $max_attempts ]; then
      echo
      echo "[ERROR] $error_message"
      exit "$exit_code_on_error"
    fi
  done
  echo
}

# --- Sprawdzenie zasobów ---
function check_resources() {
  echo "[CHECK] Zasoby..."
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  CPU=$(nproc)
  DISK=$(df -m / | awk 'NR==2 {print $4}')
  if [ "$RAM" -lt 3800 ]; then echo "[ERROR] RAM: $RAM MB < 3800MB. Rozważ większą instancję."; exit 1; fi
  if [ "$CPU" -lt 2 ]; then echo "[ERROR] CPU: $CPU < 2"; exit 1; fi
  if [ "$DISK" -lt 2800 ]; then echo "[ERROR] DYSK: $DISK MB < 2800MB"; exit 1; fi
  if [ "$(swapon --show | wc -l)" -eq 0 ]; then
    echo "[INFO] Tworzę SWAP 2GB..."
    fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
}

# --- Instalacja Dockera ---
function install_docker() {
  echo "[ETAP 1/5] Instalacja Dockera..."
  DOCKER_IS_ACTIVE=false
  if systemctl is-active --quiet docker; then DOCKER_IS_ACTIVE=true; fi

  REINSTALL_DOCKER_CHOICE="n"
  if "$DOCKER_IS_ACTIVE"; then
    read -t 10 -p "Reinstalować Dockera (y/N)? (N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo
    REINSTALL_DOCKER_CHOICE="${USER_INPUT:-n}"
  fi

  if [[ "$REINSTALL_DOCKER_CHOICE" =~ ^[Yy]$ || "$DOCKER_IS_ACTIVE" == "false" ]]; then
    echo "[INFO] Instaluję Dockera..."
    yum install -y docker || apt-get install -y docker.io
    systemctl enable --now docker
    usermod -a -G docker ec2-user
    systemctl is-active --quiet docker && echo "[VERIFY][DOCKER]=OK" || { echo "[VERIFY][DOCKER]=ERROR"; exit 2; }
  else
    echo "[INFO] Pomijam instalację Dockera."
    echo "[VERIFY][DOCKER]=OK (istniejący)"
  fi
}

# --- Instalacja K3s ---
function install_k3s() {
  echo "[ETAP 2/5] Instalacja K3s..."
  K3S_BINARY_EXISTS=false
  if [ -f /usr/local/bin/k3s ]; then K3S_BINARY_EXISTS=true; fi

  REINSTALL_K3S_CHOICE="n"
  if "$K3S_BINARY_EXISTS"; then
    read -t 10 -p "Reinstalować K3s (y/N)? (N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo
    REINSTALL_K3S_CHOICE="${USER_INPUT:-n}"
  fi

  if [[ "$REINSTALL_K3S_CHOICE" =~ ^[Yy]$ || "$K3S_BINARY_EXISTS" == "false" ]]; then
    echo "[INFO] Instaluję K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -

    echo "[INFO] Upewniam się, że usługa K3s jest uruchomiona..."
    sudo systemctl daemon-reload
    sudo systemctl enable k3s
    sudo systemctl start k3s
    sudo systemctl is-active --quiet k3s && echo "[VERIFY][K3S_SERVICE]=OK" || { echo "[VERIFY][K3S_SERVICE]=ERROR"; exit 20; }

    export PATH=$PATH:/usr/local/bin
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    mkdir -p /home/ec2-user/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
    chown ec2-user:ec2-user /home/ec2-user/.kube/config
    chmod 600 /home/ec2-user/.kube/config
    chmod -R a+r /var/lib/rancher/k3s/server/tls/
    sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|g' /home/ec2-user/.kube/config
    sed -i '/server: https:\/\/127.0.0.1:6443/a \ \ insecure-skip-tls-verify: true' /home/ec2-user/.kube/config
    export KUBECONFIG=/home/ec2-user/.kube/config

    wait_for_condition 30 5 \
      "kubectl --kubeconfig /home/ec2-user/.kube/config cluster-info 2>&1 | grep -q \"Kubernetes control plane is running\"" \
      "K3s API niegotowe" \
      "K3s API gotowe" \
      "K3s API nie startuje!" 21 \
      "sudo journalctl -u k3s --since \"30s\" --no-pager -n 5"
  else
    echo "[INFO] Pomijam instalację K3s."
  fi
}

# --- Instalacja Helm ---
function install_helm() {
  echo "[ETAP 3/5] Instalacja Helm..."

  HELM_IS_FUNCTIONAL=false
  export PATH=$PATH:/usr/local/bin
  if command -v helm &>/dev/null && /usr/local/bin/helm version --client &>/dev/null; then
    HELM_IS_FUNCTIONAL=true
    echo "[INFO] Helm jest już zainstalowany."
  fi

  REINSTALL_HELM_CHOICE="n"
  if "$HELM_IS_FUNCTIONAL"; then
    read -t 10 -p "Reinstalować Helm (y/N)? (N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo
    REINSTALL_HELM_CHOICE="${USER_INPUT:-n}"
  fi

  if [[ "$REINSTALL_HELM_CHOICE" =~ ^[Yy]$ || "$HELM_IS_FUNCTIONAL" == "false" ]]; then
    echo "[INFO] Instaluję Helm..."
    HELM_INSTALL_SCRIPT="/tmp/get_helm.sh"
    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$HELM_INSTALL_SCRIPT"
    chmod +x "$HELM_INSTALL_SCRIPT"
    sudo "$HELM_INSTALL_SCRIPT" || true
    rm -f "$HELM_INSTALL_SCRIPT"

    if command -v helm &>/dev/null && /usr/local/bin/helm version --client &>/dev/null; then
      echo "[VERIFY][HELM]=OK"
    else
      echo "[VERIFY][HELM]=ERROR: Helm nie zainstalowany."
      exit 3
    fi
  else
    echo "[INFO] Pomijam instalację Helm."
    echo "[VERIFY][HELM]=OK (istniejący)"
  fi
}

# --- Instalacja Jenkinsa ---
function install_jenkins() {
  echo "[ETAP 4/5] Instalacja Jenkinsa przez Helm..."
  JENKINS_NAMESPACE_EXISTS=false
  if kubectl get namespace jenkins &>/dev/null; then JENKINS_NAMESPACE_EXISTS=true; fi

  SHOULD_INSTALL_JENKINS=false
  if "$JENKINS_NAMESPACE_EXISTS"; then
    read -t 10 -p "Wykryto Jenkinsa. Usunąć i reinstalować (y/N)? (N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo
    REINSTALL_JENKINS_CHOICE="${USER_INPUT:-n}"

    if [[ "$REINSTALL_JENKINS_CHOICE" =~ ^[Yy]$ ]]; then
      SHOULD_INSTALL_JENKINS=true
    else
      JENKINS_POD_EXISTS=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
      if [ -z "$JENKINS_POD_EXISTS" ]; then
        echo "[WARN] NS Jenkinsa istnieje, ale podów brak. Wymuszam instalację."
        SHOULD_INSTALL_JENKINS=true
      else
        echo "[INFO] Pomijam instalację Jenkinsa."
        SHOULD_INSTALL_JENKINS=false
      fi
    fi
  else
    SHOULD_INSTALL_JENKINS=true
  fi

  if "$SHOULD_INSTALL_JENKINS"; then
    echo "[INFO] Instaluję Jenkinsa..."
    echo "[INFO] Usuwam stary NS 'jenkins'..."
    kubectl delete namespace jenkins --force --grace-period=0 || true

    wait_for_condition 20 5 \
      "kubectl get namespace jenkins --no-headers 2>/dev/null | grep -q \"NOT_FOUND\" || true" \
      "Oczekiwanie na usunięcie NS 'jenkins'" \
      "NS 'jenkins' usunięty" \
      "NS 'jenkins' nie zniknął po 100s. Kontynuuję, mogą być problemy." 0

    echo "[INFO] Tworzę NS 'jenkins'..."
    kubectl create namespace jenkins || true
    sleep 5

    echo "[INFO] Dodaję repo Helm Jenkinsa..."
    sudo -E /usr/local/bin/helm --kubeconfig /home/ec2-user/.kube/config repo add jenkinsci https://charts.jenkins.io || true
    sudo -E /usr/local/bin/helm --kubeconfig /home/ec2-user/.kube/config repo update

    /usr/local/bin/helm --kubeconfig /home/ec2-user/.kube/config upgrade --install jenkins jenkinsci/jenkins \
      --namespace jenkins \
      --set controller.serviceType=NodePort \
      --set controller.nodePort=30080 \
      --set persistence.enabled=true \
      --set persistence.size=2Gi \
      --set persistence.storageClass=local-path \
      --set controller.resources.requests.cpu=100m \
      --set controller.resources.requests.memory=768Mi \
      --set controller.resources.limits.cpu=1000m \
      --set controller.resources.limits.memory=2Gi \
      --set controller.startupProbe.initialDelaySeconds=120 \
      --set controller.periodSeconds=10 \
      --set controller.startupProbe.failureThreshold=3 \
      --set controller.livenessProbe.initialDelaySeconds=300 \
      --set controller.livenessProbe.periodSeconds=10 \
      --set controller.livenessProbe.failureThreshold=3 \
      --set controller.readinessProbe.initialDelaySeconds=300 \
      --set controller.readinessProbe.periodSeconds=10 \
      --set controller.readinessProbe.failureThreshold=3

    wait_for_condition 60 5 \
      "kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath=\"{.items[0].status.phase}\" 2>/dev/null | grep -q \"Running\" && \
       kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath=\"{.items[0].status.containerStatuses[?(@.name=='jenkins')].ready}\" 2>/dev/null | grep -q \"true\"" \
      "Pod Jenkinsa niegotowy" \
      "Pod Jenkinsa gotowy" \
      "Pod Jenkinsa nie wystartował!" 25 \
      "kubectl --kubeconfig /home/ec2-user/.kube/config logs \"\$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}')\" -n jenkins --tail=50 || true"
  else
    echo "[INFO] Pominięto instalację Jenkinsa."
  fi
}

# --- Instalacja SonarQube ---
function install_sonarqube() {
  echo "[ETAP 5/5] Instalacja SonarQube..."
  MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
  if [ "$MEM_TOTAL" -lt 2000 ]; then
    echo "[ERROR] Za mało RAM dla SonarQube (<4GB)"
    return 1
  fi

  SONARQUBE_CONTAINER_RUNNING=false
  if docker ps -a --filter "name=sonarqube" --format "{{.Names}}" | grep -q "sonarqube"; then
    if docker ps --filter "name=sonarqube" --format "{{.Status}}" | grep -q "Up"; then
      SONARQUBE_CONTAINER_RUNNING=true
      echo "[INFO] Kontener SonarQube jest już uruchomiony."
    else
      echo "[INFO] Kontener SonarQube istnieje, ale nie jest uruchomiony."
    fi
  fi

  REINSTALL_SONARQUBE_CHOICE="n"
  if "$SONARQUBE_CONTAINER_RUNNING"; then
    read -t 10 -p "Wykryto uruchomiony SonarQube. Usunąć i reinstalować (y/N)? (N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo
    REINSTALL_SONARQUBE_CHOICE="${USER_INPUT:-n}"
  fi

  SHOULD_INSTALL_SONARQUBE=false
  if [[ "$REINSTALL_SONARQUBE_CHOICE" =~ ^[Yy]$ ]]; then
    SHOULD_INSTALL_SONARQUBE=true
  elif [[ "$SONARQUBE_CONTAINER_RUNNING" == "false" ]]; then
    SHOULD_INSTALL_SONARQUBE=true
  fi

  if "$SHOULD_INSTALL_SONARQUBE"; then
    echo "[INFO] Usuwam istniejący kontener SonarQube..."
    docker rm -f sonarqube || true
    
    echo "[INFO] Uruchamiam kontener SonarQube..."
    docker run -d --name sonarqube -p 9000:9000 \
      --memory=2048m \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      -e SONAR_WEB_JAVAOPTS="-Xmx768m -Xms512m" \
      sonarqube:community
  else
    echo "[INFO] Pomijam instalację SonarQube."
  fi

  wait_for_condition 30 5 \
    "curl -s http://localhost:9000 > /dev/null" \
    "SonarQube nie odpowiada" \
    "SonarQube HTTP gotowe" \
    "SonarQube nie działa na 9000!" 23
}

# --- Główna sekwencja skryptu ---
check_resources
install_docker
install_k3s
install_helm
install_jenkins
install_sonarqube

# --- Czekanie na Jenkins (dostępność HTTP z zewnątrz) ---
echo "[INFO] Oczekiwanie na gotowość Jenkinsa na porcie 30080 (lokalnie)..."
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
if [ -z "$EC2_PUBLIC_IP" ]; then
  echo "[ERROR] Nie udało się pobrać publicznego IP instancji."
  EC2_PUBLIC_IP="<PUBLIC_IP_NIEZNANY>"
fi

# Sprawdzenie lokalnego nasłuchiwania portu 30080
wait_for_condition 20 5 \
  "HTTP_STATUS=$(curl -s -o /dev/null -w \"%\{http_code\}\" --max-time 2 http://localhost:30080); [ \"\$HTTP_STATUS\" -ne \"000\" ]" \
  "Port 30080 nie nasłuchuje" \
  "Port 30080 nasłuchuje lokalnie" \
  "Port 30080 nie otwarty lokalnie po 100s. Jenkins może mieć problem." 26 \
  "ss -tuln | grep \":30080\" || echo \"Brak nasłuchiwania na porcie 30080.\""

# Sprawdzenie dostępności HTTP Jenkinsa lokalnie
wait_for_condition 60 5 \
  "HTTP_STATUS=$(curl -s -o /dev/null -w \"%\{http_code\}\" --max-time 5 http://localhost:30080/login); [ \"\$HTTP_STATUS\" -ne \"000\" ]" \
  "Jenkins nie odpowiada na localhost:30080" \
  "Jenkins HTTP gotowy na localhost:30080" \
  "Jenkins nie działa na porcie 30080 lokalnie!" 22 \
  "kubectl --kubeconfig /home/ec2-user/.kube/config logs \"\$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}')\" -n jenkins --tail=50 || true"

# --- Podsumowanie ---
echo "[INFO] Instalacja zakończona sukcesem!"
echo "[INFO] Jenkins dostępny pod adresem: http://${EC2_PUBLIC_IP}:30080/login"
echo "[IMP] Jeśli nadal problem (np. 'ERR_CONNECTION_TIMED_OUT'), sprawdź port 30080 w Security Group i Network ACLs."
echo "[IMP] Jenkins może potrzebować jeszcze kilku minut na pełne uruchomienie."
/etc/profile.d/status_services.sh
