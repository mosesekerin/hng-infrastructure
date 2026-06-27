# Production Environment Configuration
# Copy this to terraform.tfvars and fill in your values

aws_region       = "us-east-1"
instance_type    = "t3.micro"
root_volume_size = 20
key_name         = "hng-infrastructure" # SSH key pair in AWS
domain_name      = "yourdomain.com"     # Your domain
enable_dns       = true

# IMPORTANT: Set to your public IP for SSH access
# Get your IP: curl https://ifconfig.me
allowed_ssh_cidrs = ["YOUR_IP_HERE/32"]

# VPC/Network
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
