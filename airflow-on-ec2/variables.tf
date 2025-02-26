variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 20.04 LTS"
  type        = string
  default     = "ami-03f65b8614a860c29" # Ubuntu 20.04 LTS in us-west-2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.large"
} 