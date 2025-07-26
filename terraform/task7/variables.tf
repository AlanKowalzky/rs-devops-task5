# terraform/task7/variables.tf

variable "k3s_kubeconfig_path" {
  description = "Ścieżka do pliku kubeconfig klastra K3s (np. z terraform/task6)."
  type        = string
  # Domyślna wartość, jeśli plik kubeconfig jest w standardowej lokalizacji
  # lub jeśli wiesz, gdzie go umieścisz po wygenerowaniu przez task6.
  # Zastąp to rzeczywistą ścieżką, jeśli jest inna.
  # Użyj forward slashy '/' zamiast backslashy '\' dla ścieżek
  default     = "C:/prog_AWS_DEVOPS/rs-devops-course-task4-5/terraform/task7/k3s_kubeconfig_task6.yaml"
}
