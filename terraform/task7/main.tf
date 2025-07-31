# terraform/task7/main.tf

module "prometheus" {
  source                  = "./modules/prometheus"
  namespace               = var.namespace
  helm_release_name       = var.prometheus_helm_release_name
  prometheus_service_type = var.prometheus_service_type
}

module "grafana" {
  source            = "./modules/grafana"
  namespace         = var.namespace
  helm_release_name = var.grafana_helm_release_name
  admin_password    = var.grafana_admin_password
  
  depends_on = [module.prometheus]
}
