output "prometheus_namespace_used" {
  description = "Namespace używany przez Prometheus"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_deployment_name" {
  description = "Nazwa deploymentu Prometheus"
  value       = kubernetes_deployment.prometheus.metadata[0].name
}

output "prometheus_service_name" {
  description = "Nazwa serwisu Prometheus"
  value       = kubernetes_service.prometheus.metadata[0].name
}

output "prometheus_deployment_ready" {
  description = "Status gotowości deploymentu"
  value       = kubernetes_deployment.prometheus.spec[0].replicas
}
