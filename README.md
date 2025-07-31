# End-to-End CI/CD and Monitoring on Kubernetes

This project automates the deployment of a complete environment on AWS, featuring a K3s Kubernetes cluster, a Jenkins CI/CD pipeline, and a full monitoring stack with Prometheus, Grafana, and Alertmanager. The entire infrastructure and configuration are managed as code using Terraform and Helm.

## 🏗️ Architecture & Repository Structure

The project deploys all services onto a single EC2 instance running K3s. The monitoring stack is installed into a dedicated `monitoring` namespace.

```
├── monitoring/
│   ├── alertmanager/
│   │   └── alertmanager-config.yaml   # Alertmanager routes and receivers
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   └── k8s-cluster-dashboard.json # Dashboard definition
│   │   └── datasources/
│   │       └── datasources.yaml         # Prometheus data source config
│   └── prometheus/
│       └── rules/
│           └── node-alerts.yaml         # Alerting rules for cluster resources
├── scripts/
│   └── aws_ec2_small_task6_sonar_opisy.sh # EC2 user_data script
├── terraform/
│   ├── main.tf                          # Main Terraform file for all resources
│   ├── variables.tf                     # Variable definitions
│   ├── outputs.tf                       # Outputs for service URLs
│   └── terraform.tfvars.example         # Example secrets file
└── README.md                            # This documentation
```

## 🚀 How to Run

### 1. Prerequisites
- Terraform installed.
- AWS CLI installed and configured (`aws configure`).
- An SSH key pair available at `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`.

### 2. Configure Secrets
Create a `terraform.tfvars` file inside the `terraform/` directory. **Do not commit this file to Git.** Use `terraform.tfvars.example` as a template.

```hcl
# terraform/terraform.tfvars

grafana_admin_password = "YourSuperSecretPassword123!"

# SMTP server settings (e.g., for Gmail with an App Password)
smtp_host      = "smtp.gmail.com:587"
smtp_from      = "your.email@gmail.com"
smtp_user      = "your.email@gmail.com"
smtp_password  = "YourGmailAppPassword" # Use an App Password, not your account password
alert_email_to = "your.alert.recipient@example.com"
```

### 3. Deploy the Environment
Run the following commands to create the EC2 instance, install K3s, and deploy the entire Jenkins and monitoring stack.

```bash
cd terraform
terraform init
terraform apply --auto-approve
```

This process will take several minutes as it installs and configures all services.

## 🔍 Accessing and Verifying Services

After `terraform apply` completes, the output will display the public IP address and direct URLs for all services.

| Service | URL | Username | Password |
|--------------|------------------------------------|:----------:|:----------------------------------|
| **Jenkins** | `http://<EC2_PUBLIC_IP>:30080` | - | (Initial password in logs) |
| **SonarQube** | `http://<EC2_PUBLIC_IP>:9000` | `admin` | `admin` |
| **Grafana** | `http://<EC2_PUBLIC_IP>:30300` | `admin` | (From `terraform.tfvars`) |
| **Prometheus** | `http://<EC2_PUBLIC_IP>:30090` | - | - |
| **Alertmanager**| `http://<EC2_PUBLIC_IP>:30093` | - | - |

### What to Check (Verification Steps)

1.  **Prometheus**:
    - Navigate to `Status -> Rules`. You should see the `node-alerts` group with `NodeHighCpuUsage` and `NodeLowMemory` rules.
    - Navigate to `Status -> Targets`. Verify that targets like `kubelet` and `node-exporter` are `UP`.
    - In the expression browser, query a metric like `node_cpu_seconds_total` to see a graph.

2.  **Grafana**:
    - Log in using the password from your `terraform.tfvars` file.
    - Go to `Configuration -> Data Sources`. The `Prometheus` data source should be pre-configured and working.
    - Go to `Dashboards`. Find and open the `K8s Cluster Basic Metrics` dashboard. It should display CPU usage graphs.

3.  **Alertmanager**:
    - Navigate to the Alertmanager URL and check the `Status` page to see that the configuration has been loaded correctly.
    - To test an alert, you can temporarily lower a threshold in `monitoring/prometheus/rules/node-alerts.yaml` (e.g., change CPU usage to `> 1`), re-run `terraform apply`, and wait for the alert to enter a `Firing` state. You should receive an email.

## ✅ Verification Checklist & Scoring (100 points)

This checklist helps track progress and ensures all evaluation criteria are met. The checkboxes for implemented features are already marked (`[x]`). The empty checkboxes (`[ ]`) are for the required screenshots you need to add to your Pull Request.

### Core Infrastructure & Automation (30 points)
- [x] **IaC Deployment (10 pts)**: The entire environment is deployed via a single `terraform apply`.
- [x] **CI/CD Services (10 pts)**: Jenkins and SonarQube are installed and accessible via the `user_data` script.
- [x] **Configuration as Code (10 pts)**: All monitoring configurations (alerts, dashboards, etc.) are managed in the Git repository.

### Prometheus & Grafana Setup (35 points)
- [x] **Prometheus & Grafana Running (10 pts)**: The `kube-prometheus-stack` is successfully deployed via Helm.
    - **Proof**: `[ ]` Screenshot of `kubectl get all -n monitoring`.
- [x] **Grafana Admin Secret (10 pts)**: The Grafana admin password is managed securely via a Kubernetes secret (injected by Terraform).
- [x] **Grafana Data Source (5 pts)**: The Prometheus data source is configured as code.
    - **Proof**: `[ ]` Screenshot of the Grafana Data Source configuration page.
- [x] **Grafana Dashboard (10 pts)**: A custom dashboard is created and provisioned from a JSON file.
    - **Proof**: `[ ]` Screenshot of the `K8s Cluster Basic Metrics` dashboard.

### Alerting with Alertmanager (25 points)
- [x] **Alert Rules Defined (10 pts)**: Alert rules for high CPU and low memory are defined in a YAML file.
    - **Proof**: `[ ]` Screenshot of the rules in the Prometheus UI (`Status -> Rules`).
- [x] **Alertmanager SMTP Configured (10 pts)**: SMTP settings are configured via code, with secrets passed securely.
    - **Proof**: `[ ]` Screenshot of the Alertmanager `Status` page showing the configuration.
- [x] **Alerts Received (5 pts)**: Alerts are successfully delivered via email.
    - **Proof**: `[ ]` Screenshot of a received alert email (in `Firing` state).

### Documentation & Submission (10 points)
- [x] **Comprehensive README (10 pts)**: This `README.md` file is up-to-date and documents the entire process.
- **Final PR**: Includes all required screenshots to validate the points above.

**Note**: Remember to hide or blur any personal data (like email addresses) in screenshots.

## 🧹 Cleanup

To destroy all created resources and avoid AWS charges, run:

```bash
cd terraform
terraform destroy --auto-approve
```
