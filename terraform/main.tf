terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "next_pyon" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "next-pyon-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "next_pyon" {
  vpc_id = aws_vpc.next_pyon.id

  tags = {
    Name        = "next-pyon-igw"
    Environment = var.environment
  }
}

# Public Subnets (Upper half of VPC CIDR block)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.next_pyon.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "next-pyon-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.next_pyon.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "next-pyon-public-2"
    Environment = var.environment
  }
}

# Private Subnets (Lower half of VPC CIDR block)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.next_pyon.id
  cidr_block        = "10.0.128.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "next-pyon-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.next_pyon.id
  cidr_block        = "10.0.129.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "next-pyon-private-2"
    Environment = var.environment
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.next_pyon.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.next_pyon.id
  }

  tags = {
    Name        = "next-pyon-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2
resource "aws_security_group" "web" {
  name        = "next-pyon-web-sg"
  description = "Allow SSH and HTTP to EC2 instance"
  vpc_id      = aws_vpc.next_pyon.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ポート 80 (HTTP) は、ALB 有効化状態によって外側の aws_security_group_rule で制御
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "next-pyon-web-sg"
    Environment = var.environment
  }
}

# EC2 Security Group Rule for direct HTTP (Structure 2 - ALB Disabled)
resource "aws_security_group_rule" "web_http_direct" {
  count             = var.enable_alb ? 0 : 1
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "Allow direct HTTP access from the internet"
}

# EC2 Security Group Rule for HTTP via ALB (Structure 4 - ALB Enabled)
resource "aws_security_group_rule" "web_http_via_alb" {
  count                    = var.enable_alb ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = aws_security_group.web.id
  description              = "Allow HTTP access only from ALB"
}

# ALB Security Group (Structure 4 only)
resource "aws_security_group" "alb" {
  count       = var.enable_alb ? 1 : 0
  name        = "next-pyon-alb-sg"
  description = "Allow HTTP access from the internet to ALB"
  vpc_id      = aws_vpc.next_pyon.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name        = "next-pyon-alb-sg"
    Environment = var.environment
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "next-pyon-rds-sg"
  description = "Allow access to RDS PostgreSQL from EC2"
  vpc_id      = aws_vpc.next_pyon.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "next-pyon-rds-sg"
    Environment = var.environment
  }
}

# RDS DB Subnet Group (Private Subnets)
resource "aws_db_subnet_group" "db" {
  name       = "next-pyon-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name        = "next-pyon-db-subnet-group"
    Environment = var.environment
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "db" {
  identifier             = "next-pyon-rds"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t4g.micro"
  db_name                = var.rds_db_name
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name        = "next-pyon-rds"
    Environment = var.environment
  }
}

# S3 Bucket for deployment artifacts (ソースコード zip 置き場)
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "deploy" {
  bucket        = "next-pyon-deploy-bucket-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "next-pyon-deploy-bucket"
    Environment = var.environment
  }
}

# Application Load Balancer (Structure 4 only)
resource "aws_lb" "alb" {
  count              = var.enable_alb ? 1 : 0
  name               = "next-pyon-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "next-pyon-alb"
    Environment = var.environment
  }
}

# Target Group (Structure 4 only)
resource "aws_lb_target_group" "tg" {
  count       = var.enable_alb ? 1 : 0
  name        = "next-pyon-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.next_pyon.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "next-pyon-tg"
    Environment = var.environment
  }
}

# ALB Listener (Structure 4 only)
resource "aws_lb_listener" "listener" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
}

# Target Group Attachment (Structure 4 only)
resource "aws_lb_target_group_attachment" "attachment" {
  count            = var.enable_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.tg[0].arn
  target_id        = aws_instance.web.id
  port             = 80
}

# AMI Datasource for Ubuntu 24.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    # Create 2GB Swap space to prevent out-of-memory issues
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Update package list and install prerequisites (including unzip & awscli)
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git unzip awscli

    # Install Docker official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker CE and Plugins
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and Enable Docker
    systemctl start docker
    systemctl enable docker

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Prepare app directory and environment variables
    mkdir -p /home/ubuntu/app
    
    # Download deploy.zip from S3 (if it exists) and deploy
    # (First creation won't have the zip file yet, it will fail silently and be deployed by deploy.sh)
    aws s3 cp s3://${aws_s3_bucket.deploy.bucket}/deploy.zip /home/ubuntu/app/deploy.zip || true
    
    if [ -f /home/ubuntu/app/deploy.zip ]; then
      unzip -o /home/ubuntu/app/deploy.zip -d /home/ubuntu/app/
      rm /home/ubuntu/app/deploy.zip
      
      # Generate .env with DB connection string
      echo "DATABASE_URL=postgresql://${var.rds_username}:${var.rds_password}@${aws_db_instance.db.endpoint}/${var.rds_db_name}" > /home/ubuntu/app/.env
      
      # Start docker containers
      cd /home/ubuntu/app
      docker compose -f compose.prod.yaml up -d --build
    fi

    chown -R ubuntu:ubuntu /home/ubuntu/app
  EOF
  user_data_replace_on_change = true

  tags = {
    Name        = "next-pyon-web"
    Environment = var.environment
  }
}
