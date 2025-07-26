# terraform/task7/modules/prometheus/main.tf

# Definicja przestrzeni nazw Kubernetes dla monitoringu
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
  # Ustawienie wait_for_default_service_account na false, jeśli nie jest potrzebne
  # i chcesz uniknąć potencjalnych opóźnień/problemów z tworzeniem SA.
  wait_for_default_service_account = false
}

# Instalacja Prometheus za pomocą Helm
resource "helm_release" "prometheus" {
  # Nazwa wydania Helm
  name       = var.helm_release_name
  # Przestrzeń nazw, w której zostanie zainstalowany Prometheus
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # Jawne określenie repozytorium Helm
  repository = "https://charts.bitnami.com/bitnami"
  # Nazwa wykresu w repozytorium
  chart      = "prometheus"

  # Wersja wykresu (zalecane, aby zapewnić powtarzalność)
  # Sprawdź najnowszą stabilną wersję na https://artifacthub.io/packages/helm/bitnami/prometheus
  # version    = "20.0.0" # Użyj aktualnej wersji, np. 20.0.0 lub nowszej
  version     = "2.1.15"
  # Konfiguracja wartości dla wykresu Helm (odpowiednik --set)
  # Używamy składni 'set = []' dla nowszych wersji providera Helm
  set {
  name  = "server.service.type"
  value = var.prometheus_service_type
}

set {
  name  = "kube-state-metrics.enabled"
  value = "true"
}

set {
  name  = "node-exporter.enabled"
  value = "true"
}

set {
  name  = "alertmanager.enabled"
  value = "false"
}


  # Opcjonalnie: Możesz użyć 'values' do przekazania bardziej złożonej konfiguracji YAML
  # values = [
  #   file("${path.module}/values.yaml")
  # ]

  # Czekaj na zakończenie wdrożenia
  wait = true
  # Czas oczekiwania na wdrożenie (np. 10 minut)
  timeout = 600
}
