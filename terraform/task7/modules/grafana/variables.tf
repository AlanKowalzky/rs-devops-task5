variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "monitoring"
}

variable "helm_release_name" {
  description = "Nazwa release Helm dla Grafana"
  type        = string
  default     = "grafana"
}

variable "admin_password" {
  description = "Hasło administratora Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}
