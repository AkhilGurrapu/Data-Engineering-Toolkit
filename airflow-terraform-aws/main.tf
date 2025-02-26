terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Security Group
resource "aws_security_group" "airflow_sg" {
  name        = "airflow-security-group"
  description = "Security group for Airflow EC2 instance"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Airflow Webserver"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "airflow-sg"
  }
}

# Create a key pair
resource "aws_key_pair" "airflow_key_pair" {
  key_name   = "airflow-key-pair"
  public_key = tls_private_key.airflow_key.public_key_openssh
}

# Generate private key
resource "tls_private_key" "airflow_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.airflow_key.private_key_pem
  filename        = "${path.module}/airflow-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "airflow_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.airflow_sg.id]
  key_name              = aws_key_pair.airflow_key_pair.key_name
  
  user_data = filebase64("${path.module}/userdata.sh")
  
  tags = {
    Name = "airflow-instance"
  }
  
  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }
}