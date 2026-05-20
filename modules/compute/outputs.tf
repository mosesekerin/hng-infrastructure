output "instance_id" {
  value       = aws_instance.web.id
  description = "EC2 instance ID"
}

output "public_ip" {
  value       = aws_eip.web.public_ip
  description = "Public IP address"
}

output "private_ip" {
  value       = aws_instance.web.private_ip
  description = "Private IP address"
}

output "availability_zone" {
  value       = aws_instance.web.availability_zone
  description = "Availability zone"
}
