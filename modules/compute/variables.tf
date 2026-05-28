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
  default     = "Timileyin-Your-SRE-Guy"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "infra.mosesekerin.name.ng"
}

variable "certbot_email" {
  description = "Email for Let's Encrypt"
  type        = string
  default     = "mosesekerin@gmail.com"
}
