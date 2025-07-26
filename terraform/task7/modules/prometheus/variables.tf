# terraform/task7/modules/prometheus/variables.tf

variable "namespace" {
  description = "The Kubernetes namespace for monitoring components."
  type        = string
  default     = "monitoring"
}

variable "helm_release_name" {
  description = "The Helm release name for Prometheus."
  type        = string
  default     = "my-prometheus"
}

variable "prometheus_service_type" {
  description = "The service type for the Prometheus server (e.g., ClusterIP, NodePort, LoadBalancer)."
  type        = string
  default     = "ClusterIP" # Zapewnia, że Prometheus nie jest wystawiony na zewnątrz
}
