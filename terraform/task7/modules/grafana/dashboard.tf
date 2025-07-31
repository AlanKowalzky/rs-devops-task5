resource "kubernetes_config_map" "grafana_dashboard" {
  metadata {
    name      = "k8s-dashboard"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "k8s-dashboard.json" = jsonencode({
      dashboard = {
        id = null
        title = "Kubernetes Cluster Monitoring"
        tags = ["kubernetes"]
        timezone = "browser"
        panels = [
          {
            id = 1
            title = "CPU Usage"
            type = "stat"
            targets = [
              {
                expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[2m])) * 100)"
                legendFormat = "CPU Usage %"
              }
            ]
            gridPos = { h = 8, w = 12, x = 0, y = 0 }
          },
          {
            id = 2
            title = "Memory Usage"
            type = "stat"
            targets = [
              {
                expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
                legendFormat = "Memory Usage %"
              }
            ]
            gridPos = { h = 8, w = 12, x = 12, y = 0 }
          }
        ]
        time = {
          from = "now-1h"
          to = "now"
        }
        refresh = "5s"
      }
    })
  }
}
