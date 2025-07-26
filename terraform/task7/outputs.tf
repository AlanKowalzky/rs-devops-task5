# terraform/task7/outputs.tf

# Prometheus outputs
output "prometheus_namespace_used" {
  description = "Namespace używany przez Prometheus"
  value       = module.prometheus.prometheus_namespace_used
}

output "prometheus_deployment_name" {
  description = "Nazwa deploymentu Prometheus"
  value       = module.prometheus.prometheus_deployment_name
}

output "prometheus_service_name" {
  description = "Nazwa serwisu Prometheus"
  value       = module.prometheus.prometheus_service_name
}

# Grafana outputs
output "grafana_release_name" {
  description = "Nazwa release Grafana"
  value       = module.grafana.grafana_release_name
}

output "grafana_namespace" {
  description = "Namespace Grafana"
  value       = module.grafana.grafana_namespace
}

output "grafana_admin_secret" {
  description = "Nazwa secret z hasłem admin"
  value       = module.grafana.grafana_admin_secret
  sensitive   = true
}


# URLs
output "prometheus_url" {
  description = "URL do Prometheus (przez NodePort)"
  value       = "http://PUBLICZNE_IP:30090"
}

output "grafana_url" {
  description = "URL do Grafana"
  value       = "http://PUBLICZNE_IP:30300"
}

output "jenkins_url" {
  description = "URL do Jenkins"
  value       = "http://PUBLICZNE_IP:30080"
}

# Instrukcje
output "next_steps" {
  description = "Następne kroki"
  value = <<EOF
1. Otwórz porty w AWS Security Groups:
   - 30080 (Jenkins)
   - 30090 (Prometheus) 
   - 30300 (Grafana)

2. Dostęp do usług:
   - Jenkins: http://PUBLICZNE_IP:30080
   - Prometheus: http://PUBLICZNE_IP:30090
   - Grafana: http://PUBLICZNE_IP:30300 (admin/admin123)

3. Skonfiguruj Grafana:
   - Dodaj Prometheus data source: http://prometheus.monitoring.svc.cluster.local:9090
   - Importuj dashboard dla Kubernetes
   - Skonfiguruj alerty
EOF
}
