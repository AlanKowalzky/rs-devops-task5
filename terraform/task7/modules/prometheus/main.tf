# terraform/task7/modules/prometheus/main.tf - ROZWIĄZANIE 1

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        container {
          image = "prom/prometheus:latest"
          name  = "prometheus"
          
          port {
            container_port = 9090
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}
# Dodaj do modules/prometheus/main.tf na końcu
data "kubernetes_service" "prometheus_service" {
  metadata {
    name      = kubernetes_service.prometheus.metadata[0].name
    namespace = kubernetes_service.prometheus.metadata[0].namespace
  }
  depends_on = [kubernetes_service.prometheus]
}
