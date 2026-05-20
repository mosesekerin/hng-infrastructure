# HNG Infrastructure - Terraform IaC

Production-grade Infrastructure as Code for deploying a hardened, monitored web server on AWS.

## Overview

This repository contains Terraform code to deploy:
- **VPC + Networking:** Isolated network with public subnet
- **EC2 Instance:** Ubuntu 22.04 LTS (t3.micro)
- **Security:** Security groups, SSH hardening, UFW firewall
- **DNS:** Route 53 A records for your domain
- **Monitoring:** Prometheus, Grafana, Loki (Phase 4+)
- **Web Server:** Nginx with HTTPS (Phase 3)

## Architecture
Internet
|
Route 53 DNS (yourdomain.com)
|
Elastic IP (static public IP)
|
AWS Security Group (cloud firewall)
|
EC2 Instance (Ubuntu 22.04)
├── Nginx (reverse proxy, HTTPS)
├── Prometheus (metrics)
├── Grafana (dashboards)
├── Loki (logs)
└── UFW (host firewall)

## Quick Start

### Prerequisites

- AWS account with IAM user (AdministratorAccess)
- AWS CLI configured: `aws configure`
- Terraform >= 1.5.0
- SSH key pair created in AWS EC2
- GitHub account

### Setup

1. **Clone this repository**
```bash
   git clone https://github.com/mosesekerin/hng-infrastructure.git
   cd hng-infrastructure
```

2. **Create S3 bucket for Terraform state**
```bash
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   BUCKET_NAME="hng-terraform-state-${ACCOUNT_ID}"
   
   aws s3 mb s3://${BUCKET_NAME} --region us-east-1
   aws s3api put-bucket-versioning \
     --bucket ${BUCKET_NAME} \
     --versioning-configuration Status=Enabled
   aws s3api put-bucket-encryption \
     --bucket ${BUCKET_NAME} \
     --server-side-encryption-configuration '{
       "Rules": [{
         "ApplyServerSideEncryptionByDefault": {
           "SSEAlgorithm": "AES256"
         }
       }]
     }'
```

3. **Create DynamoDB table for state locking**
```bash
   aws dynamodb create-table \
     --table-name hng-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
     --region us-east-1
```

4. **Update Terraform backend**
```bash
   # Replace ACCOUNT_ID in environments/prod/main.tf
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   sed -i "s/hng-terraform-state-ACCOUNT_ID/hng-terraform-state-${ACCOUNT_ID}/" \
     environments/prod/main.tf
```

5. **Configure variables**
```bash
   cp environments/prod/example.tfvars environments/prod/terraform.tfvars
   vim environments/prod/terraform.tfvars
   
   # Edit:
   # - allowed_ssh_cidrs = ["YOUR_IP/32"]
   # - domain_name = "yourdomain.com"
   # - key_name = "hng-infrastructure"
```

6. **Deploy**
```bash
   cd environments/prod
   terraform init
   terraform plan
   terraform apply
```

7. **Access your instance**
```bash
   # Get outputs
   terraform output -json | jq .
   
   # SSH in
   ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@<public_ip>
```

## Project Structure
hng-infrastructure/
├── README.md                    # This file
├── ARCHITECTURE.md              # Detailed architecture docs
├── DEPLOYMENT_LOG.md            # Deployment history
├── .gitignore                   # Git ignore rules
├── .github/
│   └── workflows/               # CI/CD pipelines (Phase 6)
├── environments/
│   ├── dev/                     # Development environment
│   ├── staging/                 # Staging environment
│   └── prod/                    # Production environment
│       ├── main.tf              # Root module
│       ├── variables.tf         # Input variables
│       ├── outputs.tf           # Outputs
│       ├── terraform.tfvars     # Variable values (gitignored)
│       ├── example.tfvars       # Example config
│       └── backend.tf           # Remote state config
├── modules/
│   ├── networking/              # VPC, subnet, IGW
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/                 # EC2 instance
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── user_data.sh
│   │   └── README.md
│   ├── security/                # Security groups, IAM
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── dns/                     # Route 53
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── scripts/
├── plan.sh                  # Terraform plan helper
├── apply.sh                 # Terraform apply helper
├── destroy.sh               # Destroy infrastructure
└── output.sh                # View outputs

## Environment Management

### Deploy to Different Environments

```bash
# Dev environment
cd environments/dev
terraform init
terraform plan
terraform apply

# Staging environment
cd environments/staging
terraform init
terraform plan
terraform apply

# Production environment (recommended)
cd environments/prod
terraform init
terraform plan
terraform apply
```

Each environment has its own:
- State file (separate S3 key)
- Variables (terraform.tfvars)
- Resource naming (prod-*, dev-*, staging-*)

## State Management

### Remote State (S3)

Terraform state is stored in S3 for:
- **Sharing:** Entire team sees current infrastructure
- **Locking:** DynamoDB prevents simultaneous changes
- **Backup:** S3 versioning enabled
- **Security:** Encryption enabled

View state:
```bash
aws s3 ls s3://hng-terraform-state-${ACCOUNT_ID}/prod/
aws s3 cp s3://hng-terraform-state-${ACCOUNT_ID}/prod/terraform.tfstate ./
```

### State Locking

DynamoDB table prevents concurrent `terraform apply`:
```bash
aws dynamodb scan --table-name hng-terraform-locks
```

## AWS Costs

Estimated monthly costs:

| Service | Cost |
|---------|------|
| EC2 t3.micro (free tier eligible) | $10 |
| EBS 20GB gp3 (free tier eligible) | $2 |
| Elastic IP (free when associated) | $0 |
| Data transfer | $1-5 |
| **Total** | **~$15/month** |

**First 12 months:** Most costs covered by AWS free tier.

## Security Considerations

✅ **Implemented:**
- SSH key-only authentication (no passwords)
- Root login disabled
- UFW firewall (host-level)
- Security groups (cloud-level)
- EBS encryption
- Auto security updates
- Terraform state encryption

⚠️ **To Configure:**
- Restrict Prometheus/Grafana access (currently 0.0.0.0/0)
- Use VPN for monitoring access
- Enable MFA for AWS IAM

## Phases

### Phase 1: AWS + Terraform ✅ (Current)
- [x] VPC setup
- [x] EC2 instance
- [x] Security groups
- [x] Remote state
- [x] SSH access

### Phase 2: Linux Hardening (Next)
- [ ] Fail2Ban
- [ ] Advanced SSH hardening
- [ ] Security scanning
- [ ] Systemd hardening

### Phase 3: Nginx (Next)
- [ ] Install Nginx
- [ ] HTTPS with Let's Encrypt
- [ ] Production configuration
- [ ] Health checks

### Phase 4: Monitoring
- [ ] Prometheus
- [ ] Grafana dashboards
- [ ] Alerting

### Phase 5: Logging
- [ ] Loki installation
- [ ] Promtail configuration
- [ ] Log dashboards

### Phase 6: CI/CD
- [ ] GitHub Actions
- [ ] Terraform validation
- [ ] Automated deployment

## Troubleshooting

### Terraform Issues

**Error: "bucket does not exist"**
```bash
# Bucket name must match exactly
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "hng-terraform-state-${ACCOUNT_ID}"
```

**Error: "InvalidUserID.NotFound"**
```bash
# Verify AWS credentials
aws sts get-caller-identity
aws configure list
```

### SSH Access Issues

**Error: "Permission denied (publickey)"**
```bash
# Verify key permissions
ls -la ~/.ssh/hng-infrastructure.pem
# Should be: -rw------- (600)

# Verify security group allows SSH
aws ec2 describe-security-groups --group-ids sg-xxx
```

### DNS Issues

**Domain not resolving**
```bash
# DNS takes 5-15 minutes to propagate
nslookup yourdomain.com

# Or check Route 53 directly
aws route53 list-resource-record-sets --hosted-zone-id Z...
```

## Contributing

This is a personal project, but follows best practices:
- All infrastructure changes via `terraform apply`
- No manual SSH changes (use user_data)
- All secrets in environment variables, not code
- State always in remote S3

## Learning Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [Terraform State Management](https://www.terraform.io/language/state)
- [SRE Best Practices](https://sre.google/books/)

## License

MIT License - See LICENSE file

## Author

Timileyin (@mosesekerin)

---

**Last Updated:** 2024-01-15  
**Status:** Phase 1 Complete  
**Next Phase:** Linux Hardening
