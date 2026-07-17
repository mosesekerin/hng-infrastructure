variable "domain_name" {
  description = "Domain name for A record (e.g., infra.mosesekerin.name.ng)"
  type        = string
}

variable "parent_domain" {
  description = "Parent domain for Route 53 zone lookup (e.g., mosesekerin.name.ng)"
  type        = string
}

variable "elastic_ip" {
  description = "Elastic IP address"
  type        = string
}

variable "create_www_record" {
  description = "Create www subdomain record"
  type        = bool
  default     = true
}

variable "instance_public_ip" {
  description = "Public IP of the instance to point domain to"
  type        = string
  default     = ""
}

variable "create_dns" {
  description = "Whether to create DNS records for infra subdomain"
  type        = bool
  default     = true
}

