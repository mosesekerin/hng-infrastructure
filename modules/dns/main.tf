# Data source: Get hosted zone
data "aws_route53_zone" "main" {
  name = var.parent_domain
}

# A record pointing to Elastic IP
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [var.elastic_ip]

  depends_on = [
    data.aws_route53_zone.main
  ]
}

# Optional: www subdomain
resource "aws_route53_record" "www" {
  count   = var.create_www_record ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.elastic_ip]
}
