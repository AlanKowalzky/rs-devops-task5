provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "k3s_sg" {
  name        = "k3s-sg-task6"
  description = "Allow SSH, NodePort for Jenkins, and SonarQube"

  # Reguła dla SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Dostęp z dowolnego miejsca dla SSH
    description = "Allow SSH access"
  }

  # Reguła dla Jenkins NodePort
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Dostęp z dowolnego miejsca dla Jenkins NodePort
    description = "Allow Jenkins NodePort access"
  }

  # Reguła dla SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Dostęp z dowolnego miejsca dla SonarQube
    description = "Allow SonarQube access"
  }
  # NOWA REGUŁA: Zezwól na dostęp do API K3s (port 6443)
  ingress {
    description = "Allow K3s API access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Możesz ograniczyć do swojego IP dla większego bezpieczeństwa
  }

  # Reguła dla ruchu wychodzącego (domyślnie zezwala na wszystko)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "k3s" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = var.instance_type // domyślnie t2.small (ustaw w variables.tf)
  key_name        = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  user_data = file("${path.module}/../../scripts/aws_ec2_small_task6_sonar.sh")

  # Konfiguracja głównego dysku (root)
  root_block_device {
    volume_size = 20 # Rozmiar dysku głównego w GB
    volume_type = "gp2"
    encrypted   = false
  }

  # Konfiguracja dodatkowego dysku EBS
  ebs_block_device {
    device_name   = "/dev/sdh" # Nazwa urządzenia dla dodatkowego dysku
    volume_size   = 20         # Rozmiar dodatkowego dysku w GB
    volume_type   = "gp2"
  }

  tags = {
    Name = "k3s-ec2-task6"
  }
}

// Port 30080 otwarty w SG – domyślny NodePort dla Jenkins
// Port 22 otwarty do SSH
// Port 9000 otwarty dla SonarQube
// Brak portów 443 i 8080 – nie są używane przez Jenkins na NodePort
