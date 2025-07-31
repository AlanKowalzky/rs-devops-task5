#!/bin/bash
set -e

# --- Skrypt statusowy do /etc/profile.d (zawsze na początku) ---
cat <<'EOF' | sudo tee /etc/profile.d/status_services.sh > /dev/null
#!/bin/bash
function show_status() {
  echo "\n==== STAN USŁUG (auto-refresh: ./status_services.sh loop) ===="
  systemctl is-active --quiet docker && echo "[STATUS] Docker: OK" || echo "[STATUS] Docker: ERROR"
  systemctl is-active --quiet k3s && echo "[STATUS] K3s: OK" || echo "[STATUS] K3s: ERROR"
  kubectl get nodes &>/dev/null && echo "[STATUS] K3s API: OK" || echo "[STATUS] K3s API: ERROR"
  JENKINS_POD=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
  [ "$JENKINS_POD" = "Running" ] && echo "[STATUS] Jenkins: OK" || echo "[STATUS] Jenkins: $JENKINS_POD"
  docker ps | grep -q sonarqube && echo "[STATUS] SonarQube: CONTAINER OK" || echo "[STATUS] SonarQube: CONTAINER ERROR"
  ss -tuln | grep -q 9000 && echo "[STATUS] SonarQube: PORT 9000 OK" || echo "[STATUS] SonarQube: PORT 9000 ERROR"
  curl -s http://localhost:9000 > /dev/null && echo "[STATUS] SonarQube: HTTP OK" || echo "[STATUS] SonarQube: HTTP ERROR"
  echo "[USAGE] RAM: $(free -m | awk '/Mem:/ {print $3\"/\"$2\"MB\"}') | CPU: $(nproc) | DYSK: $(df -h / | awk 'NR==2 {print $3\"/\"$2}')"
}
if [ "$1" = "loop" ]; then
  while true; do clear; show_status; sleep 10; done
else
  show_status
fi
EOF
sudo chmod +x /etc/profile.d/status_services.sh
if ! grep -q 'status_services.sh' /home/ec2-user/.bash_profile; then
  echo '/etc/profile.d/status_services.sh' >> /home/ec2-user/.bash_profile
fi

LOGFILE=/var/log/userdata-jenkins-install.log
exec > >(tee -a $LOGFILE) 2>&1

# --- Sprawdzenie zasobów i SWAP ---
echo "[user-data][CHECK] Sprawdzam zasoby..."
RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)
DISK=$(df -m /dev/xvda | awk 'NR==2 {print $4}')
if [ "$RAM" -lt 2096 ]; then echo "[user-data][ERROR] Za mało RAM: $RAM MB (min. 4096MB)"; exit 1; fi
if [ "$CPU" -lt 2 ]; then echo "[user-data][ERROR] Za mało CPU: $CPU (min. 2)"; exit 1; fi
if [ "$DISK" -lt 20000 ]; then echo "[user-data][ERROR] Za mało dysku: $DISK MB (min. 20000MB)"; exit 1; fi
if [ "$(swapon --show | wc -l)" -eq 0 ]; then
  echo "[user-data][INFO] Tworzę SWAP 2GB..."
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Instalacja Dockera ---
echo "[user-data][ETAP 1/5] Instalacja Dockera..."
yum install -y docker || apt-get install -y docker.io
systemctl start docker && systemctl enable docker
usermod -a -G docker ec2-user
systemctl is-active --quiet docker && echo "[user-data][VERIFY][DOCKER]=OK" || { echo "[user-data][VERIFY][DOCKER]=ERROR"; exit 2; }
echo "[user-data][USAGE][DOCKER]=RAM: $(free -m | awk '/Mem:/ {print $3"/"$2"MB"}') CPU: $(nproc) DYSK: $(df -h / | awk 'NR==2 {print $3"/"$2}')"

# --- Deinstalacja K3s (ze spinnerem) ---
echo "[user-data][WAIT] Deinstalacja K3s... (to może potrwać do minuty)"
(/usr/local/bin/k3s-uninstall.sh || true; rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/systemd/system/k3s*) &
pid=$!
spin='-\|/'
i=0
while kill -0 $pid 2>/dev/null; do
  i=$(( (i+1) %4 ))
  printf "\r[user-data][WAIT] Deinstalacja K3s... %s" "${spin:$i:1}"
  sleep 1
done
wait $pid
echo

# --- Instalacja K3s (ze spinnerem) ---
echo "[user-data][WAIT] Instalacja K3s... (to może potrwać kilka minut)"
(curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -) &
pid=$!
i=0
while kill -0 $pid 2>/dev/null; do
  i=$(( (i+1) %4 ))
  printf "\r[user-data][WAIT] Instalacja K3s... %s" "${spin:$i:1}"
  sleep 1
done
wait $pid
echo
sleep 5

# --- Naprawa kubeconfig ---
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo mkdir -p /home/ec2-user/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
sudo chmod 600 /home/ec2-user/.kube/config
sudo chmod -R a+r /var/lib/rancher/k3s/server/tls/
sudo sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|g' /home/ec2-user/.kube/config
sudo sed -i '/server: https:\/\/127.0.0.1:6443/a \ \ insecure-skip-tls-verify: true' /home/ec2-user/.kube/config
export KUBECONFIG=/home/ec2-user/.kube/config

# --- Czekanie na gotowość K3s API (z licznikiem) ---
echo "[user-data] Oczekiwanie na gotowość K3s API..."
for i in {1..30}; do
  percent=$((i*100/30))
  bar=$(printf '%0.s#' $(seq 1 $((percent/5))))
  if kubectl get nodes &>/dev/null; then
    echo "[user-data][READY][K3S][API]=OK po $((i*5))s [$percent%%] [$bar]"
    break
  fi
  echo -ne "[user-data][WAIT] K3s API niegotowe, czekam 5s... ($i/30) [$percent%%] [$bar]\r"
  sleep 5
  if [ $i -eq 30 ]; then
    echo
    echo "[user-data][ERROR] K3s API nie wystartowało po 150s! Przerywam instalację."
    exit 21
  fi
done
echo

# --- Instalacja Helm ---
echo "[user-data][ETAP 2/5] Instalacja Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
command -v helm && echo "[user-data][VERIFY][HELM]=OK" || { echo "[user-data][VERIFY][HELM]=ERROR"; exit 3; }
echo "[user-data][USAGE][HELM]=RAM: $(free -m | awk '/Mem:/ {print $3"/"$2"MB"}') CPU: $(nproc) DYSK: $(df -h / | awk 'NR==2 {print $3"/"$2}')"

# --- Instalacja Jenkinsa przez Helm ---
echo "[user-data][ETAP 3/5] Instalacja Jenkinsa przez Helm..."
kubectl create namespace jenkins || true
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
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
# --- Czekanie na gotowość Jenkinsa (port 30080, licznik) ---
echo "[user-data] Oczekiwanie na gotowość Jenkinsa na porcie 30080..."
for i in {1..30}; do
  percent=$((i*100/30))
  bar=$(printf '%0.s#' $(seq 1 $((percent/5))))
  if ss -tuln | grep -q 30080; then
    echo "[user-data][READY][JENKINS][PORT]=OK po $((i*5))s [$percent%%] [$bar]"
    break
  fi
  echo -ne "[user-data][WAIT] Jenkins nie nasłuchuje na 30080, czekam 5s... ($i/30) [$percent%%] [$bar]\r"
  sleep 5
  if [ $i -eq 30 ]; then
    echo
    echo "[user-data][ERROR] Jenkins nie wystartował na 30080 po 150s! Przerywam instalację."
    exit 22
  fi
  STATUS=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.phase}')
  echo -ne " [user-data][WAIT] Jenkins pod status: $STATUS\r"
done
echo

# --- Instalacja SonarQube ---
echo "[user-data][ETAP 4/5] Instalacja SonarQube..."
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
if [ "$MEM_TOTAL" -lt 4000 ]; then
  echo "[user-data][ERROR] Za mało RAM do uruchomienia SonarQube! (min. 4GB, masz: ${MEM_TOTAL}MB)"
  echo "[user-data][ERROR] SonarQube nie zostanie uruchomiony. Zalecane: osobna maszyna lub EC2 t3.large (8GB) jeśli chcesz uruchomić Jenkins, K3s i SonarQube razem."
  SONARQUBE_SKIP=1
else
  SONARQUBE_SKIP=0
fi
if [ "$SONARQUBE_SKIP" -eq 0 ]; then
  if [ "$MEM_TOTAL" -ge 6000 ]; then
    docker run -d --name sonarqube -p 9000:9000 \
      --memory=3072m \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      -e SONAR_WEB_JAVAOPTS="-Xmx1536m -Xms1024m" \
      sonarqube:community
  else
    docker run -d --name sonarqube -p 9000:9000 \
      --memory=2048m \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      -e SONAR_WEB_JAVAOPTS="-Xmx768m -Xms512m" \
      sonarqube:community
  fi
fi
# --- Czekanie na gotowość SonarQube (HTTP 9000, licznik) ---
echo "[user-data] Oczekiwanie na gotowość SonarQube na porcie 9000..."
for i in {1..30}; do
  percent=$((i*100/30))
  bar=$(printf '%0.s#' $(seq 1 $((percent/5))))
  if curl -s http://localhost:9000 > /dev/null; then
    echo "[user-data][READY][SONARQUBE][HTTP]=OK po $((i*5))s [$percent%%] [$bar]"
    break
  fi
  echo -ne "[user-data][WAIT] SonarQube nie odpowiada na HTTP 9000, czekam 5s... ($i/30) [$percent%%] [$bar]\r"
  sleep 5
  if [ $i -eq 30 ]; then
    echo
    echo "[user-data][ERROR] SonarQube nie wystartował na 9000 po 150s! Przerywam instalację."
    exit 23
  fi
done
echo

# --- Podsumowanie ---
echo "[user-data][SUMMARY] Wszystkie usługi zainstalowane i zweryfikowane."
echo "[user-data][INFO] Jenkins: http://<PUBLICZNY_IP_EC2>:30080 (login: admin, hasło: admin)"
echo "[user-data][INFO] SonarQube: http://<PUBLICZNY_IP_EC2>:9000 (login: admin, hasło: admin)"
echo "[user-data][INFO] Po zalogowaniu przez SSH zobaczysz status usług i zasobów." 