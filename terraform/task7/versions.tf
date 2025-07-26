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
      version = ">= 2.0.0"
    }
      
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.9.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
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
  cluster_name      = local.kubeconfig_parsed.contexts[0].context.cluster
  cluster_details   = [for c in local.kubeconfig_parsed.clusters : c.cluster if c.name == local.cluster_name][0]

  user_name         = local.kubeconfig_parsed.contexts[0].context.user
  user_details      = [for u in local.kubeconfig_parsed.users : u.user if u.name == local.user_name][0]
}

# Konfiguracja providera Kubernetes
provider "kubernetes" {
  host               = local.cluster_details.server
  client_certificate = base64decode(local.user_details.client-certificate-data)
  client_key         = base64decode(local.user_details.client-key-data)
  insecure           = true
}

# Konfiguracja providera Helm
provider "helm" {
  kubernetes {
    host               = local.cluster_details.server
    client_certificate = base64decode(local.user_details.client-certificate-data)
    client_key         = base64decode(local.user_details.client-key-data)
    insecure           = true
  }
}
