# Prosta aplikacja Flask – Wdrożenie na Kubernetes z Helm

## ✅ Checklista wymagań

- [x] Dockerfile do budowy obrazu aplikacji
- [x] Katalog `app/` z aplikacją Flask i requirements.txt
- [x] Helm Chart w `helm/flask-app/` (deployment, service, values)
- [x] Skrypty automatyzujące (Terraform, user-data, deploy, screenshot)
- [x] Workflow GitHub Actions do budowy i publikacji obrazu
- [x] README z instrukcją uruchomienia i checklistą
- [x] Automatyczna instalacja dashboardu K8s i instrukcja tunelowania
- [x] Obsługa NodePort i Security Group
- [x] Diagnostyka i troubleshooting

---

## Plan uruchomienia środowiska

### 1. Utwórz infrastrukturę (EC2, Security Group)
```bash
cd terraform
terraform init
terraform apply
```
Po zakończeniu zapisz publiczny IP EC2 (wyświetli się na końcu).

### 2. Automatyczne wdrożenie aplikacji, dashboardu i port-forward
```bash
cd ../scripts
./local_deploy_and_screenshot.sh
```
Skrypt:
- Skopiuje pliki na EC2,
- Uruchomi zdalnie skrypt wdrożeniowy,
- Zainstaluje K3s, Helm, dashboard, aplikację,
- Ustawi kubeconfig i port-forward do dashboardu,
- Wyświetli adres aplikacji i instrukcję tunelowania do dashboardu.

### 3. Dostęp do aplikacji
Otwórz w przeglądarce:
```
http://<PUBLICZNY_IP_EC2>:30080
```

### 4. Dostęp do dashboardu Kubernetes
- Na EC2 port-forward działa automatycznie (port 8001).
- Na swoim komputerze uruchom tunel SSH:
  ```bash
  ssh -i ~/.ssh/id_rsa -L 8001:localhost:8001 ec2-user@<PUBLICZNY_IP_EC2>
  ```
- Otwórz w przeglądarce:
  ```
  https://localhost:8001
  ```
  (może być ostrzeżenie o certyfikacie – zignoruj)

### 5. Logowanie do dashboardu
- Potrzebujesz tokena:
  ```bash
  kubectl -n kubernetes-dashboard create token admin-user
  ```
  (jeśli nie masz admin-user, patrz dokumentacja K8s dashboard)
- Skopiuj token i wklej w oknie logowania dashboardu.

### 6. Diagnostyka i naprawa typowych problemów
- Jeśli `kubectl` zgłasza błąd uprawnień:
  ```bash
  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown $(id -u):$(id -g) ~/.kube/config
  sudo chmod 600 ~/.kube/config
  export KUBECONFIG=~/.kube/config
  ```
  (dodaj `export KUBECONFIG=~/.kube/config` do `~/.bashrc` dla trwałości)
- Jeśli dashboard nie działa lokalnie – sprawdź, czy tunel SSH jest aktywny i port-forward działa na EC2.

### 7. Usuwanie środowiska
Po zakończeniu testów:
```bash
cd terraform
terraform destroy
```

---

## Automatyzacja CI/CD (GitHub Actions)
- Po każdym pushu do `main` lub `task-5` obraz Dockera jest automatycznie budowany i publikowany na DockerHub.
- Wymagane sekrety repozytorium:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

---

## Parametry Helm (fragment values.yaml)
```yaml
image:
  repository: alandocke/flask_app
  tag: latest
service:
  type: NodePort
  port: 8080
  nodePort: 30080
```

---

## Troubleshooting
- Jeśli coś nie działa, sprawdź logi na EC2:
  ```bash
  tail -n 50 /var/log/userdata-helm-install.log
  tail -n 50 ~/dashboard-portforward.log
  kubectl get pods -A
  kubectl get svc -A
  ```
- Upewnij się, że Security Group EC2 pozwala na ruch na port 30080 (NodePort) i 22 (SSH).

---

## Podsumowanie
Z tym repozytorium możesz w pełni automatycznie uruchomić aplikację Flask na K3s (AWS EC2), mieć dostęp do dashboardu K8s i korzystać z automatyzacji CI/CD. Wszystkie wymagania kursu są spełnione (patrz checklista na górze pliku). 