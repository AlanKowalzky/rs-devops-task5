# Terraform – Task6: EC2 z K3s, Helm i Jenkins

## Jak uruchomić?

1. **Wymagania:**
   - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
   - AWS CLI skonfigurowany (`aws configure`)
   - Klucz SSH w `~/.ssh/id_rsa.pub` (lub zmień ścieżkę w variables.tf)

2. **Uruchomienie:**

```bash
cd terraform/task6
terraform init
terraform apply
```

Po chwili zobaczysz publiczny adres IP EC2 oraz URL Jenkins (`jenkins_url`).

3. **Połącz się przez SSH:**

```bash
ssh -i ~/.ssh/id_rsa ec2-user@PUBLIC_IP
```

4. **Zainstaluj Jenkins przez Helm:**

```bash
kubectl create namespace jenkins
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=standard
```

5. **Dostęp do Jenkins:**

Jenkins będzie dostępny pod adresem:

```
https://PUBLIC_IP:443
```

Adres znajdziesz też w outputach Terraform jako `jenkins_url`.

6. **Hasło administratora Jenkins:**

```bash
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- cat /run/secrets/chart-admin-password
```

--- 