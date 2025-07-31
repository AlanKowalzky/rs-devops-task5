output "public_ip" {
  value = aws_instance.k3s.public_ip
  description = "Publiczny adres IP instancji EC2 z K3s (task6)"
}
