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