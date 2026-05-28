# Security Group for web server
resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Security group for web server"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-web-sg"
    Environment = var.environment
  }
}

# Inbound: SSH (port 22)
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "SSH access"
}

# Inbound: HTTP (port 80)
resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "HTTP access"
}

# Inbound: HTTPS (port 443)
resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "HTTPS access"
}

# Inbound: Prometheus (port 9090) - internal monitoring
resource "aws_security_group_rule" "prometheus" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # In production, restrict this to your IP
  security_group_id = aws_security_group.web.id
  description       = "Prometheus"
}

# Inbound: Grafana (port 3000) - internal monitoring
resource "aws_security_group_rule" "grafana" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # In production, restrict this to your IP
  security_group_id = aws_security_group.web.id
  description       = "Grafana"
}

# Outbound: Allow all (for package updates, DNS, etc.)
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "Allow all outbound"
}
