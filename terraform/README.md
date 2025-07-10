# Terraform – EC2 z K3s i Helm (najtańszy klaster na AWS)

## Jak uruchomić?

1. **Wymagania:**
   - Zainstalowany [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
   - Skonfigurowane AWS CLI (`aws configure`)
   - Klucz SSH w `~/.ssh/id_rsa.pub` (lub zmień ścieżkę w main.tf)

2. **Uruchomienie:**

```bash
cd terraform
terraform init
terraform apply
```

Po chwili zobaczysz publiczny adres IP instancji EC2 z gotowym K3s i Helm.

3. **Połącz się przez SSH:**

```bash
ssh -i ~/.ssh/id_rsa ec2-user@PUBLICZNY_IP
```

4. **Usuń infrastrukturę po testach:**

```bash
terraform destroy
```

**Uwaga:**
- Po zakończeniu testów zawsze wykonaj `terraform destroy`, by nie ponosić kosztów!
- Skrypt user-data automatycznie instaluje K3s i Helm na instancji EC2. 