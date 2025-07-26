# Task 7: Monitoring with Prometheus, Grafana, and Jenkins on Kubernetes

This project sets up a monitoring stack on Kubernetes using Prometheus and Grafana, along with a Jenkins instance for CI/CD.

## Prerequisites

-   Terraform installed
-   AWS CLI configured
-   Kubernetes cluster (e.g., K3s)
-   Helm

## Deployment Steps

1.  **Create Infrastructure:**

    ```bash
    cd terraform
    terraform init
    terraform apply
    ```

    This will create an EC2 instance and configure it with K3s and Helm. Make sure to save the public IP address of the EC2 instance.

2.  **Access Services:**

    Once the Terraform script is complete, you can access the services using the public IP address of the EC2 instance:

    -   Jenkins: `http://<EC2_PUBLIC_IP>:30080`
    -   Prometheus: `http://<EC2_PUBLIC_IP>:30090`
    -   Grafana: `http://<EC2_PUBLIC_IP>:30300` (default admin password: admin123)

3.  **Configure Grafana:**

    -   Add Prometheus as a data source: `http://prometheus.monitoring.svc.cluster.local:9090`
    -   Import Kubernetes dashboard
    -   Set up alerts

## Configuration

### Terraform Variables

-   `k3s_kubeconfig_path`: Path to the K3s kubeconfig file (default: `./k3s_kubeconfig_task6.yaml`)
-   `namespace`: Kubernetes namespace for monitoring (default: `monitoring`)
-   `prometheus_helm_release_name`: Helm release name for Prometheus (default: `my-prometheus`)
-   `prometheus_service_type`: Prometheus service type (default: `ClusterIP`)
-   `grafana_helm_release_name`: Helm release name for Grafana (default: `grafana`)
-   `grafana_admin_password`: Grafana administrator password (default: `admin123`)

### Outputs

The Terraform script will output the following:

-   `prometheus_namespace_used`: Namespace used by Prometheus
-   `prometheus_deployment_name`: Prometheus deployment name
-   `prometheus_service_name`: Prometheus service name
-   `grafana_release_name`: Grafana release name
-   `grafana_namespace`: Grafana namespace
-   `grafana_admin_secret`: Grafana administrator secret
-   `prometheus_url`: URL to access Prometheus
-   `grafana_url`: URL to access Grafana

## Modules

-   **Prometheus Module:** Deploys Prometheus using Helm.
-   **Grafana Module:** Deploys Grafana as a Kubernetes deployment and service and configures a Kubernetes ConfigMap for Grafana dashboards.

## Security

To ensure secure communication with the K3s cluster, it's crucial to configure TLS verification. This involves retrieving the CA certificate from the cluster and incorporating it into the Kubernetes provider configuration.

## Next Steps

1.  Open the necessary ports in the AWS Security Groups:
    -   30080 (Jenkins)
    -   30090 (Prometheus)
    -   30300 (Grafana)
2.  Access the services:
    -   Jenkins: `http://<EC2_PUBLIC_IP>:30080`
    -   Prometheus: `http://<EC2_PUBLIC_IP>:30090`
    -   Grafana: `http://<EC2_PUBLIC_IP>:30300` (admin/admin123)
3.  Configure Grafana:
    -   Add Prometheus data source: `http://prometheus.monitoring.svc.cluster.local:9090`
    -   Import dashboard for Kubernetes
    -   Configure alerts

## Troubleshooting

-   **`Kubernetes cluster unreachable` error:**
    -   Ensure that the K3s cluster is running and accessible.
    -   Verify that the `KUBECONFIG` environment variable is correctly set.
-   **`kubectl` not recognized:**
    -   Make sure `kubectl` is installed and added to your system's PATH.
-   **Connection issues:**
    -   Check the AWS Security Groups to ensure that ports 30080, 30090, and 30300 are open.

## K3s Cluster Health Check

To ensure the K3s cluster is healthy and fully initialized, implement a health check script that verifies the availability of essential Kubernetes services.

## Cleanup

To remove the infrastructure:

```bash
cd terraform
terraform destroy
```

## Additional Notes

This setup provides a basic monitoring solution. Consider extending it with:

-   Alerting rules in Prometheus
-   Custom dashboards in Grafana
-   Automated deployments with Jenkins


## Infrastructure Automation

Utilize Terraform to automate the provisioning of the EC2 instance, security groups, and other necessary infrastructure components. This ensures a consistent and repeatable deployment process.


## Repository Structure

```
├── app/                       # Flask application files
├── helm/                      # Helm chart for deploying the application
├── modules/
│   ├── grafana/               # Grafana module
│   └── prometheus/            # Prometheus module
├── scripts/                   # Scripts for automation
├── terraform/                 # Terraform configuration files
├── Jenkinsfile                # Jenkins pipeline definition
├── README.md                  # Documentation
└── ...
```


## Systemd Service Management

Leverage `systemd` for managing the K3s service. Use `systemctl` commands to check the status, start, stop, and enable the K3s service.

```bash
sudo systemctl status k3s
sudo systemctl start k3s
sudo systemctl stop k3s
sudo systemctl enable k3s
```

These commands are essential for maintaining the K3s cluster's lifecycle.
