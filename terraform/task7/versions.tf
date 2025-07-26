# terraform/task7/versions.tf

terraform {
  backend "s3" {
    bucket = "backendtask7"
    key    = "task7/terraform.tfstate"
    region = "eu-central-1"
  }

  required_version = ">= 1.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"}
      
   helm = {
  source  = "hashicorp/helm"
  version = "= 2.12.1"
}

    local = { # Provider 'local' jest ponownie potrzebny do odczytu pliku kubeconfig
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = { # Dodajemy provider 'null' dla null_resource
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

# Data source do odczytu zawartości pliku kubeconfig
data "local_file" "k3s_kubeconfig_content" {
  filename = var.k3s_kubeconfig_path
}

# Parsowanie zawartości YAML pliku kubeconfig
locals {
  kubeconfig_parsed = yamldecode(data.local_file.k3s_kubeconfig_content.content)
  # Zakładamy, że domyślny kontekst wskazuje na domyślny klaster i użytkownika
  # Możesz dostosować, jeśli masz bardziej złożoną konfigurację kubeconfig
  cluster_name      = local.kubeconfig_parsed.contexts[0].context.cluster
  cluster_details   = [for c in local.kubeconfig_parsed.clusters : c.cluster if c.name == local.cluster_name][0]

  user_name         = local.kubeconfig_parsed.contexts[0].context.user
  user_details      = [for u in local.kubeconfig_parsed.users : u.user if u.name == local.user_name][0]
}

# Konfiguracja providera Kubernetes
provider "kubernetes" {
  host                   = local.cluster_details.server
  cluster_ca_certificate = base64decode(local.cluster_details.certificate-authority-data)
  client_certificate     = base64decode(local.user_details.client-certificate-data)
  client_key             = base64decode(local.user_details.client-key-data)
  insecure               = true
}

# Konfiguracja providera Helm
provider "helm" {
  kubernetes {
    host                   = local.cluster_details.server
    cluster_ca_certificate = base64decode(local.cluster_details.certificate-authority-data)
    client_certificate     = base64decode(local.user_details.client-certificate-data)
    client_key             = base64decode(local.user_details.client-key-data)
    insecure               = true
  }
}


# Dodajemy sprawdzenie połączenia z klastrem K3s
resource "null_resource" "k3s_connection_check" {
  # Wywołuje się, gdy zmieni się ścieżka do kubeconfig
  triggers = {
    kubeconfig_path = var.k3s_kubeconfig_path
  }

  # Używamy Dockera, aby uruchomić kubectl bez potrzeby instalowania go lokalnie
  provisioner "local-exec" {
    # Zakładamy, że Terraform jest uruchamiany w kontenerze Dockera
    # Montujemy plik kubeconfig do kontenera
    command = <<EOT
      docker run --rm -v "${path.root}/k3s_kubeconfig_task6.yaml:/k3s_kubeconfig_task6.yaml" alpine/kubectl:latest get nodes --kubeconfig=/k3s_kubeconfig_task6.yaml --insecure-skip-tls-verify
    EOT
  }
  # Zależność od odczytania pliku kubeconfig
  depends_on = [data.local_file.k3s_kubeconfig_content]
}

output "k3s_connection_check_result" {
  description = "Wynik sprawdzenia połączenia z klastrem K3s."
  value = null_resource.k3s_connection_check.id
}
