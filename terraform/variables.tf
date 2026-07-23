variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources"
}

variable "aws_profile" {
  type        = string
  default     = "morijyobi-2026-devops"
  description = "AWS CLI profile name"
}

variable "key_name" {
  type        = string
  default     = "vockey"
  description = "SSH key pair name for EC2 instance"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Deployment environment"
}
