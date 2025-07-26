output "grafana_release_name" {
  description = "Nazwa deploymentu Grafana"
  value       = kubernetes_deployment.grafana.metadata[0].name
}

output "grafana_namespace" {
  description = "Namespace Grafana"
  value       = kubernetes_deployment.grafana.metadata[0].namespace
}

output "grafana_admin_secret" {
  description = "Hasło admin Grafana"
  value       = var.admin_password
  sensitive   = true
}
