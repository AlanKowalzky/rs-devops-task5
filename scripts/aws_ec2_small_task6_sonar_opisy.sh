#!/bin/bash
set -e
set -x
set -o pipefail # Dodane dla bardziej rygorystycznej obsługi błędów w potokach

# --- Skrypt statusowy do /etc/profile.d ---
cat <<'EOF' | sudo tee /etc/profile.d/status_services.sh > /dev/null
#!/bin/bash
function show_status() {
  echo -e "\n==== STAN USŁUG (auto-refresh: ./status_services.sh loop) ===-"
  # Upewnij się, że ścieżka do dockera jest dostępna
  export PATH=$PATH:/usr/bin:/usr/local/bin

  systemctl is-active --quiet docker && echo "[STATUS] Docker: OK" || echo "[STATUS] Docker: ERROR"
  systemctl is-active --quiet k3s && echo "[STATUS] K3s: OK" || echo "[STATUS] K3s: ERROR"

  # Użycie bardziej precyzyjnego sprawdzenia API K3s w funkcji show_status
  K3S_API_OUTPUT=$(kubectl --kubeconfig /home/ec2-user/.kube/config cluster-info 2>&1)
  if echo "$K3S_API_OUTPUT" | grep -q "Kubernetes control plane is running"; then
    echo "[STATUS] K3s API: OK"
  elif echo "$K3S_API_OUTPUT" | grep -q "The connection to the server .* was refused"; then
    echo "[STATUS] K3s API: CONNECTION REFUSED"
  elif echo "$K3S_API_OUTPUT" | grep -q "Unauthorized"; then
    echo "[STATUS] K3S API: UNAUTHORIZED"
  elif [ -z "$K3S_API_OUTPUT" ]; then
    echo "[STATUS] K3s API: NO RESPONSE"
  else
    # Domyślny status dla innych błędów lub fazy uruchamiania
    echo "[STATUS] K3s API: UNKNOWN / STARTING"
  fi

  # Sprawdzenie Jenkinsa na publicznym IP
  EC2_PUBLIC_IP_STATUS_FUNC=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "UNKNOWN_IP")
  if [ "$EC2_PUBLIC_IP_STATUS_FUNC" != "UNKNOWN_IP" ] && curl -s --max-time 5 http://${EC2_PUBLIC_IP_STATUS_FUNC}:30080/login > /dev/null; then
    echo "[STATUS] Jenkins: HTTP OK na ${EC2_PUBLIC_IP_STATUS_FUNC}:30080"
  else
    JENKINS_POD=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
    echo "[STATUS] Jenkins: $JENKINS_POD (HTTP ERROR na ${EC2_PUBLIC_IP_STATUS_FUNC}:30080)"
  fi

  docker ps | grep -q sonarqube && echo "[STATUS] SonarQube: CONTAINER OK" || echo "[STATUS] SonarQube: CONTAINER ERROR"
  ss -tuln | grep -q 9000 && echo "[STATUS] SonarQube: PORT 9000 OK" || echo "[STATUS] SonarQube: PORT 9000 ERROR"
  curl -s http://localhost:9000 > /dev/null && echo "[STATUS] SonarQube: HTTP OK" || echo "[STATUS] SonarQube: HTTP ERROR"
  echo "[USAGE] RAM: $(free -m | awk '/Mem:/ {print $3"/"$2"MB"}') | CPU: $(nproc) | DYSK: $(df -h / | awk 'NR==2 {print $3"/"$2}')"
}
if [ "$1" = "loop" ]; then
  while true; do clear; show_status; sleep 10; done
else
  show_status
fi
EOF
sudo chmod +x /etc/profile.d/status_services.sh
echo '/etc/profile.d/status_services.sh' >> /home/ec2-user/.bash_profile

# --- Logowanie ---
LOGFILE=/var/log/userdata-jenkins-install.log
# Przekieruj stdout i stderr do pliku logu, wymagane sudo
exec > >(sudo tee -a $LOGFILE) 2>&1

# --- Sprawdzenie zasobów ---
echo "[user-data][CHECK] Sprawdzam zasoby..."
RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)
DISK=$(df -m / | awk 'NR==2 {print $4}')
# Zmieniony próg RAM na 3800MB, bardziej realistyczny dla t3.medium
if [ "$RAM" -lt 3800 ]; then echo "[user-data][ERROR] RAM: $RAM MB < 3800MB. Rozważ większą instancję (np. t3.large)."; exit 1; fi
if [ "$CPU" -lt 2 ]; then echo "[user-data][ERROR] CPU: $CPU < 2"; exit 1; fi
if [ "$DISK" -lt 2800 ]; then echo "[user-data][ERROR] DYSK: $DISK MB < 2800MB"; exit 1; fi
if [ "$(swapon --show | wc -l)" -eq 0 ]; then
  echo "[user-data][INFO] Tworzę SWAP 2GB..."
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Instalacja Dockera ---
echo "[user-data][ETAP 1/5] Instalacja Dockera..."
DOCKER_IS_ACTIVE=false
if systemctl is-active --quiet docker; then
  DOCKER_IS_ACTIVE=true
fi

REINSTALL_DOCKER_CHOICE="n" # Initialize with default 'n'
if "$DOCKER_IS_ACTIVE"; then # Tylko pytaj o reinstalację, jeśli jest już aktywny
  # Prompt for input, if no input or timeout, default to 'n'
  read -t 10 -p "Czy chcesz ponownie zainstalować Dockera (y/N)? (Domyślnie: N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
  echo # Newline after read
  REINSTALL_DOCKER_CHOICE="${USER_INPUT:-n}" # Use parameter expansion for default if USER_INPUT is empty
fi

if [[ "$REINSTALL_DOCKER_CHOICE" =~ ^[Yy]$ || "$DOCKER_IS_ACTIVE" == "false" ]]; then
  echo "[user-data][INFO] Rozpoczynam instalację/reinstalację Dockera..."
  yum install -y docker || apt-get install -y docker.io
  systemctl enable --now docker
  usermod -a -G docker ec2-user
  systemctl is-active --quiet docker && echo "[user-data][VERIFY][DOCKER]=OK" || { echo "[user-data][VERIFY][DOCKER]=ERROR"; exit 2; }
else
  echo "[user-data][INFO] Pomijam instalację Dockera."
  echo "[user-data][VERIFY][DOCKER]=OK (istniejący)"
fi

# --- K3s: pytanie o reinstalację ---
K3S_BINARY_EXISTS=false
if [ -f /usr/local/bin/k3s ]; then
  K3S_BINARY_EXISTS=true
fi

REINSTALL_K3S_CHOICE="n" # Initialize with default 'n'
if "$K3S_BINARY_EXISTS"; then
  read -t 10 -p "Wykryto istniejącą instalację K3s. Czy chcesz ją ponownie zainstalować (y/N)? (Domyślnie: N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
  echo # Newline after read
  REINSTALL_K3S_CHOICE="${USER_INPUT:-n}" # Use parameter expansion for default if USER_INPUT is empty
fi

if [[ "$REINSTALL_K3S_CHOICE" =~ ^[Yy]$ || "$K3S_BINARY_EXISTS" == "false" ]]; then
  echo "[user-data][INFO] Rozpoczynam instalację/reinstalację K3s..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -

  # --- UPEWNIJ SIĘ, ŻE K3S DZIAŁA ---
  echo "[user-data][INFO] Upewniam się, że usługa K3s jest uruchomiona..."
  sudo systemctl daemon-reload # Odśwież systemd, jeśli były zmiany w plikach serwisowych
  sudo systemctl enable k3s   # Upewnij się, że jest włączona przy starcie systemu
  sudo systemctl start k3s    # Jawnie uruchom usługę K3s
  sudo systemctl is-active --quiet k3s && echo "[user-data][VERIFY][K3S_SERVICE]=OK" || { echo "[user-data][VERIFY][K3S_SERVICE]=ERROR"; exit 20; }

  # --- Konfiguracja PATH dla kubectl ---
  # K3s instaluje kubectl w /usr/local/bin, upewniamy się, że jest w PATH
  export PATH=$PATH:/usr/local/bin

  # --- Konfiguracja kubeconfig ---
  # Skopiuj kubeconfig i ustaw uprawnienia dla ec2-user
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml # Ustaw tymczasowo na oryginalny plik dla cp
  mkdir -p /home/ec2-user/.kube
  cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
  chown ec2-user:ec2-user /home/ec2-user/.kube/config
  chmod 600 /home/ec2-user/.kube/config
  chmod -R a+r /var/lib/rancher/k3s/server/tls/ # Upewnij się, że katalog TLS jest czytelny

  # Zmodyfikuj skopiowany kubeconfig do użycia localhost
  sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|g' /home/ec2-user/.kube/config
  sed -i '/server: https:\/\/127.0.0.1:6443/a \ \ insecure-skip-tls-verify: true' /home/ec2-user/.kube/config

  # Ustaw KUBECONFIG na skopiowany plik dla bieżącej sesji skryptu
  export KUBECONFIG=/home/ec2-user/.kube/config

  # Dodaj KUBECONFIG do .bash_profile użytkownika, aby działał po zalogowaniu
  echo "export KUBECONFIG=/home/ec2-user/.kube/config" >> /home/ec2-user/.bash_profile
  echo "export PATH=\$PATH:/usr/local/bin" >> /home/ec2-user/.bash_profile

  # --- Oczekiwanie na API ---
  echo "[user-data] Oczekiwanie na gotowość K3s API..."
  for i in {1..30}; do
    percent=$((i*100/30))
    bar=$(printf '%0.s#' $(seq 1 $((percent/5)) ))
    
    # Print progress message on a new line to avoid interfering with journalctl
    echo "[user-data][WAIT] K3s API niegotowe, czekam 5s... ($i/30) [$percent%%] [$bar]"

    # Capture kubectl output and its exit code for debugging and robust checking
    KUBECTL_OUTPUT=$(kubectl --kubeconfig /home/ec2-user/.kube/config cluster-info 2>&1)
    KUBECTL_STATUS=$? # Capture the exit code immediately

    echo "DEBUG: kubectl cluster-info exit code: $KUBECTL_STATUS"
    echo "DEBUG: kubectl cluster-info output: $KUBECTL_OUTPUT"

    # Check if the command succeeded (exit code 0) AND its output contains the success message
    if [ "$KUBECTL_STATUS" -eq 0 ] && [[ "$KUBECTL_OUTPUT" == *"Kubernetes control plane is running"* ]]; then
      echo "[user-data][READY][K3S][API]=OK po $((i*5))s [$percent%%] [$bar]"
      break
    fi

    # Display last few K3s logs if API is not ready
    echo "--- Ostatnie logi K3s (z ostatnich 30s) ---"
    sudo journalctl -u k3s --since "30s" --no-pager -n 5 || true # Changed "30s" to "30" for compatibility
    echo "------------------------------------------"
    
    sleep 5
    if [ $i -eq 30 ]; then
      echo
      echo "[user-data][ERROR] K3s API nie wystartowało po 150s! Przerywam instalację."
      exit 21
    fi
  done
  echo
else
  echo "[user-data][INFO] Pomijam instalację K3s."
fi


# --- Helm ---
echo "[user-data][ETAP 2/5] Instalacja Helm..."

HELM_IS_FUNCTIONAL=false
# Ensure /usr/local/bin is in PATH for command -v helm check
export PATH=$PATH:/usr/local/bin
if command -v helm &>/dev/null && /usr/local/bin/helm version --client &>/dev/null; then # Check if command exists AND is functional
  HELM_IS_FUNCTIONAL=true
  echo "[user-data][INFO] Helm jest już zainstalowany i działa poprawnie."
fi

REINSTALL_HELM_CHOICE="n" # Initialize with default 'n'
if "$HELM_IS_FUNCTIONAL"; then
  read -t 10 -p "Wykryto istniejącą i działającą instalację Helm. Czy chcesz ją ponownie zainstalować (y/N)? (Domyślnie: N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
  echo # Newline after read
  REINSTALL_HELM_CHOICE="${USER_INPUT:-n}" # Use parameter expansion for default if USER_INPUT is empty
fi

if [[ "$REINSTALL_HELM_CHOICE" =~ ^[Yy]$ || "$HELM_IS_FUNCTIONAL" == "false" ]]; then
  echo "[user-data][INFO] Rozpoczynam instalację/reinstalację Helm..."
  
  # Download Helm installation script to a temporary file
  HELM_INSTALL_SCRIPT="/tmp/get_helm.sh"
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$HELM_INSTALL_SCRIPT"
  chmod +x "$HELM_INSTALL_SCRIPT"

  # Execute the Helm installation script.
  # Use 'sudo' to ensure it has permissions to install into /usr/local/bin
  # Add || true to prevent set -e from exiting if the script itself reports non-fatal warnings.
  sudo "$HELM_INSTALL_SCRIPT" || true

  # Clean up the temporary script
  rm -f "$HELM_INSTALL_SCRIPT"

  # Verify Helm installation after running the script
  if command -v helm &>/dev/null && /usr/local/bin/helm version --client &>/dev/null; then
    echo "[user-data][VERIFY][HELM]=OK"
  else
    echo "[user-data][VERIFY][HELM]=ERROR: Helm nie został zainstalowany poprawnie lub nie jest w PATH."
    exit 3
  fi
else
  echo "[user-data][INFO] Pomijam instalację Helm."
  echo "[user-data][VERIFY][HELM]=OK (istniejący i działający)"
fi

# --- Jenkins ---
echo "[user-data][ETAP 3/5] Instalacja Jenkinsa przez Helm..."
JENKINS_NAMESPACE_EXISTS=false
if kubectl get namespace jenkins &>/dev/null; then
  JENKINS_NAMESPACE_EXISTS=true
fi

SHOULD_INSTALL_JENKINS=false

if "$JENKINS_NAMESPACE_EXISTS"; then
  REINSTALL_JENKINS_CHOICE="n" # Initialize with default 'n'
  read -t 10 -p "Wykryto istniejącą przestrzeń nazw Jenkinsa. Czy chcesz usunąć i ponownie zainstalować Jenkinsa (y/N)? (Domyślnie: N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
  echo # Newline after read
  REINSTALL_JENKINS_CHOICE="${USER_INPUT:-n}" # Use parameter expansion for default if USER_INPUT is empty

  if [[ "$REINSTALL_JENKINS_CHOICE" =~ ^[Yy]$ ]]; then
    SHOULD_INSTALL_JENKINS=true
  else
    # If namespace exists and user chose not to reinstall, then Jenkins will be skipped.
    # The current logs show "No resources found in jenkins namespace." and "services "jenkins" not found"
    # This means the namespace exists but Jenkins is not actually running.
    # In this case, we should force install Jenkins.
    # So, if namespace exists BUT Jenkins POD is NOT found, then force install.
    JENKINS_POD_EXISTS=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
    if [ -z "$JENKINS_POD_EXISTS" ]; then
      echo "[user-data][WARNING] Przestrzeń nazw Jenkinsa istnieje, ale nie znaleziono działających podów Jenkinsa. Wymuszam instalację."
      SHOULD_INSTALL_JENKINS=true
    else
      echo "[user-data][INFO] Pomijam instalację Jenkinsa zgodnie z wyborem użytkownika."
      SHOULD_INSTALL_JENKINS=false # Explicitly set to false if user skipped and pods exist
    fi
  fi
else
  # Namespace does not exist, so we should install
  SHOULD_INSTALL_JENKINS=true
fi

if "$SHOULD_INSTALL_JENKINS"; then
  echo "[user-data][INFO] Rozpoczynam instalację/reinstalację Jenkinsa..."
  # Usuń starą przestrzeń nazw Jenkinsa, aby zapewnić czysty start wszystkich zasobów
  echo "[user-data][INFO] Usuwam starą przestrzeń nazw 'jenkins'..."
  kubectl delete namespace jenkins --force --grace-period=0 || true

  # Poczekaj, aż przestrzeń nazw zostanie usunięta
  echo "[user-data][INFO] Oczekiwanie na usunięcie przestrzeni nazw 'jenkins'..."
  for i in {1..20}; do # Max 20*5=100s na usunięcie
    NS_STATUS=$(kubectl get namespace jenkins --no-headers 2>/dev/null || echo "NOT_FOUND")
    if [ "$NS_STATUS" == "NOT_FOUND" ]; then
      echo "[user-data][INFO] Przestrzeń nazw 'jenkins' usunięta."
      break
    fi
    echo "DEBUG: Czekam na usunięcie przestrzeni nazw 'jenkins' (status: $NS_STATUS)..."
    sleep 5
    if [ $i -eq 20 ]; then
      echo "[user-data][WARNING] Przestrzeń nazw 'jenkins' nie zniknęła po 100s. Kontynuuję, ale mogą wystąpić problemy."
    fi
  done

  # Utwórz przestrzeń nazw Jenkinsa na nowo
  echo "[user-data][INFO] Tworzę przestrzeń nazw 'jenkins'..."
  kubectl create namespace jenkins || true
  sleep 5 # Daj czas na utworzenie przestrzeni nazw

  # Dodaj repozytorium Helm Jenkinsa - WYMAGANE, ABY HELM MÓGŁ ZNALEŹĆ WYKRES
  echo "[user-data][INFO] Dodaję repozytorium Helm Jenkinsa..."
  sudo -E /usr/local/bin/helm --kubeconfig /home/ec2-user/.kube/config repo add jenkinsci https://charts.jenkins.io || true # Używam pełnej ścieżki i -E
  sudo -E /usr/local/bin/helm --kubeconfig /home/ec2-user/.kube/config repo update # Używam pełnej ścieżki i -E


  # Użycie 'upgrade --install' dla idempotencji
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
    --set controller.startupProbe.periodSeconds=10 \
    --set controller.startupProbe.failureThreshold=3 \
    --set controller.livenessProbe.initialDelaySeconds=300 \
    --set controller.livenessProbe.periodSeconds=10 \
    --set controller.livenessProbe.failureThreshold=3 \
    --set controller.readinessProbe.initialDelaySeconds=300 \
    --set controller.readinessProbe.periodSeconds=10 \
    --set controller.readinessProbe.failureThreshold=3

  # --- NOWA PĘTLA OCZEKIWANIA NA JENKINSA ---
  echo "[user-data] Oczekiwanie na gotowość poda Jenkinsa..."
  for i in {1..60}; do # Zwiększony limit czasu do 5 minut (60 * 5s)
    percent=$((i*100/60))
    bar=$(printf '%0.s#' $(seq 1 $((percent/5)) ))
    
    CURRENT_JENKINS_POD_STATUS=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.phase}" 2>/dev/null || echo "NOT_FOUND")
    CURRENT_JENKINS_POD_READY=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.containerStatuses[?(@.name=='jenkins')].ready}" 2>/dev/null || echo "false")
    
    echo "DEBUG: Jenkins pod status: $CURRENT_JENKINS_POD_STATUS, Ready: $CURRENT_JENKINS_POD_READY"
    
    if [ "$CURRENT_JENKINS_POD_STATUS" = "Running" ] && [ "$CURRENT_JENKINS_POD_READY" = "true" ]; then
      echo "[user-data][READY][JENKINS][POD]=OK po $((i*5))s [$percent%%] [$bar]"
      break
    fi
    
    echo -ne "[user-data][WAIT] Pod Jenkinsa niegotowy, czekam 5s... ($i/60) [$percent%%] [$bar]\r"
    sleep 5
    if [ $i -eq 60 ]; then
      echo
      echo "[user-data][ERROR] Pod Jenkinsa nie wystartował po 5 minutach! Przerywam instalację."
      exit 25 # Nowy kod błędu dla niepowodzenia uruchomienia poda Jenkinsa
    fi
  done
  echo # Newline after loop
else
  echo "[user-data][INFO] Pominięto instalację Jenkinsa zgodnie z wyborem użytkownika."
fi


# --- Czekanie na Jenkins (dostępność HTTP) ---
echo "[user-data] Oczekiwanie na gotowość Jenkinsa na porcie 30080 (publiczny IP)..."
# Pobierz publiczny IP instancji
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
if [ -z "$EC2_PUBLIC_IP" ]; then
  echo "[user-data][ERROR] Nie udało się pobrać publicznego IP instancji. Nie mogę sprawdzić Jenkinsa."
  exit 24 # Nowy kod błędu
fi

# Dodatkowa diagnostyka Jenkinsa przed pętlą oczekiwania na port
echo "--- Diagnostyka Jenkinsa (przed sprawdzeniem portu) ---"
echo "Status Podów Jenkinsa:"
kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller || true
echo "Szczegóły Usługi Jenkinsa:"
kubectl --kubeconfig /home/ec2-user/.kube/config get svc -n jenkins jenkins || true
echo "Logi poda Jenkinsa (ostatnie 50 linii):"
# Sprawdź, czy pod istnieje, zanim spróbujesz pobrać logi
JENKINS_POD_NAME=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
if [ -n "$JENKINS_POD_NAME" ]; then
  kubectl --kubeconfig /home/ec2-user/.kube/config logs "$JENKINS_POD_NAME" -n jenkins --tail=50 || true
else
  echo "Pod Jenkinsa nie znaleziono."
fi
echo "Opis poda Jenkinsa:"
if [ -n "$JENKINS_POD_NAME" ]; then
  kubectl --kubeconfig /home/ec2-user/.kube/config describe pod "$JENKINS_POD_NAME" -n jenkins || true
else
  echo "Pod Jenkinsa nie znaleziono do opisania."
fi
echo "Informacje o węźle Kubernetes (allocatable, taints):"
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if [ -n "$NODE_NAME" ]; then
  kubectl describe node "$NODE_NAME" || true
else
  echo "Nie znaleziono węzłów Kubernetes."
fi
echo "----------------------------------------------------"

for i in {1..30}; do
  percent=$((i*100/30))
  bar=$(printf '%0.s#' $(seq 1 $((percent/5)) ))
  
  # Sprawdź status poda Jenkinsa
  CURRENT_JENKINS_POD_STATUS=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
  CURRENT_JENKINS_POD_READY=$(kubectl --kubeconfig /home/ec2-user/.kube/config get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.containerStatuses[?(@.name=='jenkins')].ready}" 2>/dev/null)
  
  echo "DEBUG: Jenkins pod status: $CURRENT_JENKINS_POD_STATUS, Ready: $CURRENT_JENKINS_POD_READY"

  # Jeśli pod jest Running i Ready, sprawdź dostępność HTTP na publicznym IP
  if [ "$CURRENT_JENKINS_POD_STATUS" = "Running" ] && [ "$CURRENT_JENKINS_POD_READY" = "true" ]; then
    if curl -s --max-time 5 http://${EC2_PUBLIC_IP}:30080/login > /dev/null; then
      echo "[user-data][READY][JENKINS][HTTP]=OK na ${EC2_PUBLIC_IP}:30080 po $((i*5))s [$percent%%] [$bar]"
      break
    fi
  fi

  echo -ne "[user-data][WAIT] Jenkins nie odpowiada na ${EC2_PUBLIC_IP}:30080... ($i/30) [$percent%%] [$bar]\r"
  sleep 5
  if [ $i -eq 30 ]; then
    echo
    echo "[user-data][ERROR] Jenkins nie działa na porcie 30080 na publicznym IP!"
    exit 22
  fi
done
echo "$PATH"

# --- SonarQube ---
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
if [ "$MEM_TOTAL" -lt 2000 ]; then
  echo "[user-data][ERROR] Za mało RAM dla SonarQube (<4GB)"
  SONARQUBE_SKIP=1
else
  SONARQUBE_SKIP=0
fi
if [ "$SONARQUBE_SKIP" -eq 0 ]; then
  SONARQUBE_CONTAINER_RUNNING=false
  if docker ps -a --filter "name=sonarqube" --format "{{.Names}}" | grep -q "sonarqube"; then
    # Check if it's not just existing, but actually running
    if docker ps --filter "name=sonarqube" --format "{{.Status}}" | grep -q "Up"; then
      SONARQUBE_CONTAINER_RUNNING=true
      echo "[user-data][INFO] Kontener SonarQube jest już uruchomiony."
    else
      echo "[user-data][INFO] Kontener SonarQube istnieje, ale nie jest uruchomiony."
    fi
  fi

  REINSTALL_SONARQUBE_CHOICE="n" # Initialize with default 'n'
  if "$SONARQUBE_CONTAINER_RUNNING"; then
    read -t 10 -p "Wykryto istniejący i uruchomiony kontener SonarQube. Czy chcesz go usunąć i ponownie uruchomić (y/N)? (Domyślnie: N po 10s) " -n 1 -r USER_INPUT || USER_INPUT="n"
    echo # Newline after read
    REINSTALL_SONARQUBE_CHOICE="${USER_INPUT:-n}" # Use parameter expansion for default if USER_INPUT is empty
  fi

  SHOULD_INSTALL_SONARQUBE=false
  if [[ "$REINSTALL_SONARQUBE_CHOICE" =~ ^[Yy]$ ]]; then
    SHOULD_INSTALL_SONARQUBE=true
  elif [[ "$SONARQUBE_CONTAINER_RUNNING" == "false" ]]; then
    # If container is not running (or doesn't exist), we should install it.
    SHOULD_INSTALL_SONARQUBE=true
  fi

  if "$SHOULD_INSTALL_SONARQUBE"; then
    # Usuń istniejący kontener SonarQube, jeśli istnieje
    echo "[user-data][INFO] Usuwam istniejący kontener SonarQube (jeśli istnieje)..."
    docker rm -f sonarqube || true # Use || true to prevent script exit if container doesn't exist
    
    echo "[user-data][INFO] Uruchamiam kontener SonarQube..."
    docker run -d --name sonarqube -p 9000:9000 \
      --memory=2048m \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      -e SONAR_WEB_JAVAOPTS="-Xmx768m -Xms512m" \
      sonarqube:community
  else
    echo "[user-data][INFO] Pomijam instalację SonarQube."
  fi
fi

# --- Czekanie na SonarQube ---
echo "[user-data] Oczekiwanie na SonarQube HTTP 9000..."
for i in {1..30}; do
  percent=$((i*100/30))
  bar=$(printf '%0.s#' $(seq 1 $((percent/5)) ))
  if curl -s http://localhost:9000 > /dev/null; then
    echo "[user-data][READY][SONARQUBE][HTTP]=OK po $((i*5))s [$percent%%] [$bar]"
    break
  fi
  echo -ne "[user-data][WAIT] SonarQube nie odpowiada... ($i/30) [$percent%%] [$bar]\r"
  sleep 5
  if [ $i -eq 30 ]; then
    echo
    echo "[user-data][ERROR] SonarQube nie działa na 9000!"
    exit 23
  fi
done
echo

# --- Podsumowanie ---
echo "[user-data] Instalacja zakończona sukcesem!"
/etc/profile.d/status_services.sh
