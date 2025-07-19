output "public_ip" {
  value = aws_instance.k3s.public_ip
  description = "Publiczny adres IP instancji EC2 z K3s (task6)"
}

output "jenkins_url" {
  value = "http://${aws_instance.k3s.public_ip}:30080"
  description = "Publiczny adres URL Jenkins (NodePort 30080) na instancji EC2 z K3s (task6)"
} 