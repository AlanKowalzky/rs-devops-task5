output "public_ip" {
  value = aws_instance.k3s.public_ip
  description = "Publiczny adres IP instancji EC2 z K3s (task6)"
}

output "jenkins_url" {
  value = "https://${aws_instance.k3s.public_ip}:443"
  description = "Publiczny adres URL Jenkins (HTTPS) na instancji EC2 z K3s (task6)"
} 