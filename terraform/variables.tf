variable "aws_region" {
  description = "Region AWS do wdrożenia zasobów"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "Typ instancji EC2. Zalecane t3.medium dla Jenkins+Sonar+Monitoring."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Nazwa pary kluczy SSH w AWS"
  type        = string
  default     = "deployer-key"
}

variable "public_key_path" {
  description = "Ścieżka do publicznego klucza SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Ścieżka do prywatnego klucza SSH"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Zmienne dla sekretów (przekazywane przez terraform.tfvars)
variable "grafana_admin_password" {
  description = "Hasło administratora Grafany"
  type        = string
  sensitive   = true
}

variable "smtp_host" { description = "Adres serwera SMTP z portem"; type = string; sensitive = true }
variable "smtp_from" { description = "Adres e-mail nadawcy"; type = string; sensitive = true }
variable "smtp_user" { description = "Użytkownik SMTP"; type = string; sensitive = true }
variable "smtp_password" { description = "Hasło SMTP"; type = string; sensitive = true }
variable "alert_email_to" { description = "Adres e-mail odbiorcy alertów"; type = string; sensitive = true }
