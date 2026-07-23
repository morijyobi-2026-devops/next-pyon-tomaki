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

# 構成4用の切り替えフラグ
variable "enable_alb" {
  type        = bool
  default     = false
  description = "Enable Application Load Balancer (Structure 4). If false, directly accesses EC2 (Structure 2)"
}

# RDS設定
variable "rds_db_name" {
  type        = string
  default     = "next_pyon"
  description = "Database name for RDS"
}

variable "rds_username" {
  type        = string
  default     = "postgres"
  description = "Database master username"
}

variable "rds_password" {
  type        = string
  default     = "SuperSecurePassword123!"
  description = "Database master password"
  sensitive   = true
}
