# ==============================================================================
# Dostawcy (Providers)
# ==============================================================================
provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

# ==============================================================================
# Zmienne lokalne
# ==============================================================================
locals {
  # Ścieżka do kubeconfig, który zostanie pobrany z serwera EC2
  kubeconfig_path = "${path.module}/k3s.yaml"
}

# ==============================================================================
# Zasoby AWS (EC2, Security Group, Key Pair)
# ==============================================================================
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "k3s_sg" {
  name        = "k3s-sg"
  description = "Allow SSH and NodePort"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Zmień na swoje IP dla bezpieczeństwa
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- Porty dla Task 7: Monitoring ---
  ingress {
    from_port   = 30090 # Prometheus
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30093 # Alertmanager
    to_port     = 30093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30300 # Grafana
    to_port     = 30300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k3s_server" { # Zmieniono nazwę dla większej czytelności
  ami           = data.aws_ami.amazon_linux.id
  # UWAGA: t2.small jest za małe dla Jenkins+Sonar+Monitoring. Zalecane t3.medium.
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  # Używamy nowszego, bardziej rozbudowanego skryptu user_data
  user_data = file("${path.module}/../scripts/aws_ec2_small_task6_sonar_opisy.sh")

  root_block_device {
    volume_size = 20 # Zwiększono dysk dla kontenerów i PV
  }

  tags = {
    Name = "k3s-server-task6-task7"
  }

  # Pobranie pliku kubeconfig z serwera po jego utworzeniu
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "/dev/null" # Wymagane, ale nie używane
    destination = local.kubeconfig_path
    content     = "sudo cat /etc/rancher/k3s/k3s.yaml"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ==============================================================================
# Zasoby Kubernetes i Helm (Task 7)
# ==============================================================================

# Utworzenie przestrzeni nazw 'monitoring'
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [aws_instance.k3s_server]
}

# Wdrożenie stosu monitoringu za pomocą Helm
resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "51.6.0" # Użycie konkretnej wersji dla stabilności

  # Przekazanie konfiguracji jako wartości do chartu Helm
  values = [
    file("${path.module}/../monitoring/alertmanager/alertmanager-config.yaml"),
    file("${path.module}/../monitoring/prometheus/rules/node-alerts.yaml"),
    file("${path.module}/../monitoring/grafana/datasources/datasources.yaml")
  ]

  # Ustawienie dodatkowych wartości, w tym sekretów
  set { name = "alertmanager.config.global.smtp_from", value = var.smtp_from }
  set { name = "alertmanager.config.global.smtp_smarthost", value = var.smtp_host }
  set { name = "alertmanager.config.global.smtp_auth_username", value = var.smtp_user }
  set { name = "alertmanager.config.global.smtp_auth_password", value = var.smtp_password, type = "string" }
  set { name = "alertmanager.config.receivers[0].email_configs[0].to", value = var.alert_email_to }
  set { name = "grafana.adminPassword", value = var.grafana_admin_password, type = "string" }
  set { name = "grafana.sidecar.dashboards.enabled", value = "true" }
  set { name = "grafana.sidecar.dashboards.searchNamespace", value = "ALL" }
  set { name = "prometheus.service.type", value = "NodePort" }
  set { name = "prometheus.service.nodePort", value = "30090" }
  set { name = "grafana.service.type", value = "NodePort" }
  set { name = "grafana.service.nodePort", value = "30300" }
  set { name = "alertmanager.service.type", value = "NodePort" }
  set { name = "alertmanager.service.nodePort", value = "30093" }

  depends_on = [kubernetes_namespace.monitoring]
}

# Utworzenie ConfigMap dla dashboardu Grafany
resource "kubernetes_config_map" "grafana_dashboard" {
  metadata {
    name      = "k8s-cluster-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "k8s-cluster-dashboard.json" = file("${path.module}/../monitoring/grafana/dashboards/k8s-cluster-dashboard.json")
  }
  depends_on = [helm_release.prometheus_stack]
}
