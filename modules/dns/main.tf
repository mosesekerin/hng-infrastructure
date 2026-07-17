# Data source: Get hosted zone
data "aws_route53_zone" "main" {
  name         = var.parent_domain
  private_zone = false
}

# Create Route53 record for infra subdomain pointing to instance
resource "aws_route53_record" "infra" {
  count   = var.create_dns ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "infra.${var.parent_domain}"
  type    = "A"
  ttl     = 300
  records = [var.instance_public_ip]

  depends_on = [data.aws_route53_zone.main]
}
