# terraform/task7/main.tf

# Wywołanie modułu Prometheus
module "prometheus" {
  source = "./modules/prometheus"

  # Możesz nadpisać domyślne wartości, jeśli chcesz
  # namespace           = "my-custom-monitoring"
  # helm_release_name   = "my-custom-prometheus"
  # prometheus_service_type = "LoadBalancer" # Tylko do testów, domyślnie ClusterIP

  # Usunięto: k3s_public_ip = data.terraform_remote_state.task6.outputs.public_ip
}

# Jeśli używasz data.terraform_remote_state.task6, upewnij się, że jest ona zdefiniowana
# w tym samym pliku lub w innym pliku w głównym module.
# Przykład definicji data.terraform_remote_state (jeśli jej brakuje):
# data "terraform_remote_state" "task6" {
#   backend = "s3" # lub inny backend, którego używasz w task6
#   config = {
#     bucket = "twoja-nazwa-bucketa-terraform-states"
#     key    = "task6/k3s.tfstate"
#     region = "eu-central-1"
#   }
# }
