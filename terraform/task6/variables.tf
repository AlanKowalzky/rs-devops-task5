variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "eu-central-1"
}

variable "key_name" {
  description = "Nazwa klucza SSH do EC2"
  type        = string
  default     = "deployer-key-task6"
}

variable "public_key_path" {
  description = "Ścieżka do publicznego klucza SSH (np. ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "instance_type" {
  description = "Typ instancji EC2"
  type        = string
  default     = "t3.medium"
} 