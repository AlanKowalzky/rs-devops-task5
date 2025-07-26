# terraform/task7/outputs.tf

# Wyjście pokazujące przestrzeń nazw, w której zainstalowano Prometheus
output "prometheus_namespace_used" {
  description = "The Kubernetes namespace where Prometheus is installed."
  # Odwołanie do wyjścia z modułu Prometheus
  value       = module.prometheus.prometheus_namespace
}

# Wyjście pokazujące nazwę wydania Helm dla Prometheus
output "prometheus_helm_release_name" {
  description = "The Helm release name for Prometheus."
  # Odwołanie do wyjścia z modułu Prometheus
  value       = module.prometheus.prometheus_helm_release_name
}