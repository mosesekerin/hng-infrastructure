variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID for instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID (for EIP dependency)"
  type        = string
}

variable "hng_username" {
  description = "HNG username to display on website"
  type        = string
  default     = "Your-HNG-Username"
}

variable "deploy_public_key" {
  description = "Public key authorized for CI/CD deploys over SSH"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  # Pass via: -var="domain_name=yourdomain.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate"
  type        = string
  # Pass via: -var="letsencrypt_email=your@email.com"
}
