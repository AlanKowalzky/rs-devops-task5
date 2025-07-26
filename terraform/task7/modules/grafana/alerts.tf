# modules/grafana/alerts.tf
resource "kubernetes_config_map" "grafana_alerts" {
  metadata {
    name      = "grafana-alerts"
    namespace = var.namespace
  }

  data = {
    "alert-rules.yaml" = <<EOF
groups:
  - name: k8s-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          
      - alert: CoreDNSDown
        expr: up{job="coredns"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "CoreDNS is down"
EOF
  }
}
