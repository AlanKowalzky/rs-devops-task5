# Simple Flask Application – Deployment on Kubernetes with Helm

## ✅ Requirements Checklist

- [x] Dockerfile for building the application image
- [x] `app/` directory with Flask app and requirements.txt
- [x] Helm Chart in `helm/flask-app/` (deployment, service, values)
- [x] Automation scripts (Terraform, user-data, deploy, screenshot)
- [x] GitHub Actions workflow for building and publishing the image
- [x] README with launch instructions and checklist
- [x] Automatic installation of K8s dashboard and tunneling instructions
- [x] NodePort and Security Group configuration
- [x] Diagnostics and troubleshooting

---

## Environment Launch Plan

### 1. Create infrastructure (EC2, Security Group)
```bash
cd terraform
terraform init
terraform apply
```
After completion, save the public EC2 IP (displayed at the end).

### 2. Automatic deployment of the app, dashboard, and port-forward
```bash
cd ../scripts
./local_deploy_and_screenshot.sh
```
The script will:
- Copy files to EC2,
- Remotely run the deployment script,
- Install K3s, Helm, dashboard, and the app,
- Set up kubeconfig and port-forward to the dashboard,
- Display the app address and dashboard tunneling instructions.

### 3. Access the application
Open in your browser:
```
http://<PUBLIC_EC2_IP>:30080
```

### 4. Access the Kubernetes dashboard
- Port-forward runs automatically on EC2 (port 8001).
- On your local computer, start an SSH tunnel:
  ```bash
  ssh -i ~/.ssh/id_rsa -L 8001:localhost:8001 ec2-user@<PUBLIC_EC2_IP>
  ```
- Open in your browser:
  ```
  https://localhost:8001
  ```
  (you may see a certificate warning – ignore it)

### 5. Logging in to the dashboard
- You need a token:
  ```bash
  kubectl -n kubernetes-dashboard create token admin-user
  ```
  (if you don't have admin-user, see the K8s dashboard documentation)
- Copy the token and paste it into the dashboard login window.

### 6. Diagnostics and troubleshooting
- If `kubectl` reports a permissions error:
  ```bash
  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown $(id -u):$(id -g) ~/.kube/config
  sudo chmod 600 ~/.kube/config
  export KUBECONFIG=~/.kube/config
  ```
  (add `export KUBECONFIG=~/.kube/config` to your `~/.bashrc` for persistence)
- If the dashboard is not available locally – check if the SSH tunnel is active and port-forward is running on EC2.

### 7. Destroying the environment
After testing:
```bash
cd terraform
terraform destroy
```

---

## CI/CD Automation (GitHub Actions)
- On every push to `main` or `task-5`, the Docker image is automatically built and published to DockerHub.
- Required repository secrets:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

---

## Helm Parameters (values.yaml excerpt)
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
- If something doesn't work, check logs on EC2:
  ```bash
  tail -n 50 /var/log/userdata-helm-install.log
  tail -n 50 ~/dashboard-portforward.log
  kubectl get pods -A
  kubectl get svc -A
  ```
- Make sure the EC2 Security Group allows traffic on port 30080 (NodePort) and 22 (SSH).

---

## Summary
With this repository, you can fully automatically launch a Flask app on K3s (AWS EC2), access the K8s dashboard, and use CI/CD automation. All course requirements are met (see the checklist at the top of the file). 