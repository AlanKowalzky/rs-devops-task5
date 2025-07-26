# terraform/task7/modules/prometheus/outputs.tf

output "prometheus_namespace" {
  description = "The Kubernetes namespace where Prometheus is installed."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_helm_release_name" {
  description = "The Helm release name for Prometheus."
  value       = helm_release.prometheus.name
}