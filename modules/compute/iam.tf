# Identity for the instance: may read microapp secrets from SSM, nothing else
resource "aws_iam_role" "web" {
  name = "${var.environment}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "${var.environment}-microapp-ssm-read"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:us-east-1:*:parameter/microapp/${var.environment}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.environment}-web-profile"
  role = aws_iam_role.web.name
}
