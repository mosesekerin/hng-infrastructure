# Provider
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state
  backend "s3" {
    bucket         = "hng-terraform-state-617163942982" # CHANGE THIS
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
      Project     = "HNG-Infrastructure"
    }
  }
}

# Locals (environment-specific values)
locals {
  environment = "prod"
}

# Networking
module "networking" {
  source = "../../modules/networking"

  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

# Security
module "security" {
  source = "../../modules/security"

  vpc_id            = module.networking.vpc_id
  environment       = local.environment
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# Compute
module "compute" {
  source = "../../modules/compute"

  environment         = local.environment
  instance_type       = var.instance_type
  subnet_id           = module.networking.public_subnet_id
  security_group_id   = module.security.security_group_id
  key_name            = var.key_name
  root_volume_size    = var.root_volume_size
  internet_gateway_id = module.networking.internet_gateway_id
  hng_username        = var.hng_username
}

# DNS (if you have a Route 53 hosted zone)
module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/dns"

  domain_name       = var.domain_name
  parent_domain     = var.parent_domain
  elastic_ip        = module.compute.public_ip
  create_www_record = true
}

# Monitoring Stack (Phase 4)
module "monitoring" {
  source = "../../modules/monitoring"

  domain_name        = var.domain_name
  instance_public_ip = module.compute.public_ip
  instance_id        = module.compute.instance_id
}

# Phase 6: Testing CI/CD pipeline
# retry
