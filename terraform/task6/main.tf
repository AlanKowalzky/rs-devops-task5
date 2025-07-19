provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "k3s_sg" {
  name        = "k3s-sg-task6"
  description = "Allow SSH and NodePort for Jenkins"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type // domyślnie t2.small (ustaw w variables.tf)
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  user_data = file("${path.module}/../../scripts/ec2_userdata_k3s_jenkins.sh")

  tags = {
    Name = "k3s-ec2-task6"
  }
}

// Port 30080 otwarty w SG – domyślny NodePort dla Jenkins
// Port 22 otwarty do SSH
// Brak portów 443 i 8080 – nie są używane przez Jenkins na NodePort