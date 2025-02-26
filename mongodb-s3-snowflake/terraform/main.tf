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

# S3 Bucket
resource "aws_s3_bucket" "mongodb_data_lake" {
  bucket = var.s3_bucket_name
  
  tags = {
    Name        = "MongoDB Data Lake"
    Environment = "Production"
    Project     = "Data Pipeline"
  }
}


# IAM Role for EC2 Instance
resource "aws_iam_role" "airflow_ec2_role" {
  name = "airflow-ec2-s3-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access" {
  name        = "airflow-s3-access-policy"
  description = "Policy for Airflow to access S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.mongodb_data_lake.id}",
          "arn:aws:s3:::${aws_s3_bucket.mongodb_data_lake.id}/*"
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "s3_attachment" {
  role       = aws_iam_role.airflow_ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "airflow_profile" {
  name = "airflow-ec2-profile"
  role = aws_iam_role.airflow_ec2_role.name
}