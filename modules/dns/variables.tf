variable "domain_name" {
  description = "Domain name"
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
