# Production environment variables
aws_region       = "us-east-1"
instance_type    = "t3.micro"
root_volume_size = 20
key_name         = "hng-infrastructure"
domain_name      = "infra.mosesekerin.name.ng"
parent_domain    = "mosesekerin.name.ng"
enable_dns       = true

# IMPORTANT: Change this to YOUR IP
# Run: curl https://ifconfig.me
allowed_ssh_cidrs = ["102.93.7.11/32"]

# VPC/Network
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

# Production Environment Configuration

# Phase 3: Nginx Configuration
hng_username         = "Timileyin-Your-SRE-Guy"
letsencrypt_email    = "mosesekerin@gmail.com"
ssh_private_key_path = "~/.ssh/hng-infrastructure.pem"

