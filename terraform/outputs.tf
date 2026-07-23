output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "public_url" {
  description = "URL of the application"
  value       = "http://${aws_instance.web.public_ip}/"
}
