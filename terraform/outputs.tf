output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "public_url" {
  description = "URL of the application (ALB DNS or EC2 Public IP)"
  value       = var.enable_alb ? "http://${aws_lb.alb[0].dns_name}/" : "http://${aws_instance.web.public_ip}/"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.db.endpoint
}
