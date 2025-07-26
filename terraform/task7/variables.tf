# terraform/task7/variables.tf

variable "k3s_kubeconfig_path" {
  description = "Ścieżka do pliku kubeconfig K3s"
  type        = string
  default     = "./k3s_kubeconfig_task6.yaml"
}

variable "namespace" {
  description = "Kubernetes namespace dla monitoringu"
  type        = string
  default     = "monitoring"
}

variable "prometheus_helm_release_name" {
  description = "Nazwa release Helm dla Prometheus"
  type        = string
  default     = "my-prometheus"
}

variable "prometheus_service_type" {
  description = "Typ serwisu Prometheus"
  type        = string
  default     = "ClusterIP"
}

variable "grafana_helm_release_name" {
  description = "Nazwa release Helm dla Grafana"
  type        = string
  default     = "grafana"
}

variable "grafana_admin_password" {
  description = "Hasło administratora Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}
