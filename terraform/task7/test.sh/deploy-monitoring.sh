#!/bin/bash
# deploy-monitoring.sh - Wdrożenie Jenkins, Prometheus NodePort i przygotowanie do Grafana

echo "=== WDROŻENIE USŁUG MONITORINGU ==="
echo "Data: $(date)"
echo

# 1. Napraw uprawnienia kubeconfig
echo "1. Naprawianie uprawnień kubeconfig..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s_kubeconfig_task6.yaml
sudo chown ec2-user:ec2-user ~/k3s_kubeconfig_task6.yaml
echo "✓ Kubeconfig naprawiony"
echo

# 2. Stwórz namespace jenkins (jeśli nie istnieje)
echo "2. Tworzenie namespace jenkins..."
/usr/local/bin/k3s kubectl create namespace jenkins 2>/dev/null || echo "Namespace jenkins już istnieje"
echo

# 3. Wdróż Jenkins
echo "3. Wdrażanie Jenkins..."
/usr/local/bin/k3s kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
  selector:
    app: jenkins
EOF
echo "✓ Jenkins wdrożony"
echo

# 4. Stwórz NodePort dla Prometheus
echo "4. Tworzenie NodePort dla Prometheus..."
/usr/local/bin/k3s kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: prometheus-nodeport
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: 30090
  selector:
    app: prometheus
EOF
echo "✓ Prometheus NodePort utworzony"
echo

# 5. Poczekaj na uruchomienie podów
echo "5. Oczekiwanie na uruchomienie podów..."
echo "Jenkins:"
/usr/local/bin/k3s kubectl wait --for=condition=ready pod -l app=jenkins -n jenkins --timeout=300s
echo "Prometheus:"
/usr/local/bin/k3s kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=60s
echo

# 6. Pobierz hasło Jenkins
echo "6. Hasło administratora Jenkins:"
sleep 10  # Poczekaj na inicjalizację
/usr/local/bin/k3s kubectl exec -n jenkins deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Hasło jeszcze nie gotowe - spróbuj za chwilę"
echo

# 7. Sprawdź dostępność usług
echo "7. Status usług:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Publiczne IP: $PUBLIC_IP"
echo "Jenkins: http://$PUBLIC_IP:30080"
echo "Prometheus: http://$PUBLIC_IP:30090"
echo

# 8. Test połączeń
echo "8. Test połączeń:"
echo "Jenkins port 30080:"
sudo netstat -tlnp | grep 30080 && echo "✓ Port 30080 nasłuchuje" || echo "✗ Port 30080 nie nasłuchuje"
echo "Prometheus port 30090:"
sudo netstat -tlnp | grep 30090 && echo "✓ Port 30090 nasłuchuje" || echo "✗ Port 30090 nie nasłuchuje"
echo

echo "=== INSTRUKCJE KOŃCOWE ==="
echo "1. Otwórz porty w AWS Security Groups:"
echo "   - Port 30080 (Jenkins)"
echo "   - Port 30090 (Prometheus)"
echo "   - Source: 0.0.0.0/0"
echo
echo "2. Dostęp do usług:"
echo "   - Jenkins: http://$PUBLIC_IP:30080"
echo "   - Prometheus: http://$PUBLIC_IP:30090"
echo
echo "3. Następnie uruchom Terraform dla Grafana:"
echo "   terraform apply -auto-approve"
echo
echo "=== KONIEC WDROŻENIA ==="
