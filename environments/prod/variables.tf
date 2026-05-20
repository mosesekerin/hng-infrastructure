variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  # Pass via: -var="key_name=hng-infrastructure"
}

variable "root_volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 20
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # CHANGE THIS TO YOUR IP
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  # Pass via: -var="domain_name=yourdomain.com"
}

variable "enable_dns" {
  description = "Enable Route 53 DNS configuration"
  type        = bool
  default     = false
}
