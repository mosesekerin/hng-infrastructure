# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]

  # Storage
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.environment}-root-volume"
    }
  }

  # User data: Initial setup script
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    hng_username = var.hng_username  
  }))

  tags = {
    Name        = "${var.environment}-web-server"
    Environment = var.environment
  }

#  monitoring = true  # Enable detailed CloudWatch monitoring

  depends_on = [
    var.security_group_id
  ]
}

# Elastic IP (static public IP)
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-eip"
    Environment = var.environment
  }

  depends_on = [
    var.internet_gateway_id
  ]
}
