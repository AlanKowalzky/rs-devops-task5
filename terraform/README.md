# Terraform – EC2 with K3s and Helm (the cheapest cluster on AWS)

## How to run?

1. **Requirements:**
   - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) installed
   - AWS CLI configured (`aws configure`)
   - SSH key in `~/.ssh/id_rsa.pub` (or change the path in main.tf)

2. **Run:**

```bash
cd terraform
terraform init
terraform apply
```

After a while, you will see the public IP address of the EC2 instance with K3s and Helm ready.

3. **Connect via SSH:**

```bash
ssh -i ~/.ssh/id_rsa ec2-user@PUBLIC_IP
```

4. **Remove the infrastructure after testing:**

```bash
terraform destroy
```

**Note:**
- After testing, always run `terraform destroy` to avoid unnecessary costs!
- The user-data script automatically installs K3s and Helm on the EC2 instance. 

# Jenkins na K3s – instrukcja dla task6

Po utworzeniu infrastruktury (EC2 z K3s i Helm):

1. Zaloguj się na instancję EC2:

```bash
ssh -i ~/.ssh/id_rsa ec2-user@PUBLIC_IP
```

2. Utwórz namespace dla Jenkins:

```bash
kubectl create namespace jenkins
```

3. Zainstaluj Jenkins przez Helm z persistent volume (np. lokalny dysk lub EBS):

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=standard
```

4. Jenkins będzie dostępny pod adresem:

```
https://PUBLIC_IP:443
```

Adres znajdziesz też w outputach Terraform jako `jenkins_url`.

5. Domyślne hasło administratora Jenkins:

```bash
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- cat /run/secrets/chart-admin-password
``` 