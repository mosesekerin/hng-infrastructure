# Infrastructure Architecture

## High-Level Overview
┌─────────────────────────────────────────────────────┐
│                  AWS Account                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  Route 53 DNS                                 │ │
│  │  yourdomain.com → Elastic IP                 │ │
│  └───────────────────────────────────────────────┘ │
│                      │                              │
│  ┌───────────────────▼───────────────────────────┐ │
│  │  VPC (10.0.0.0/16)                           │ │
│  │                                               │ │
│  │  ┌─────────────────────────────────────────┐ │ │
│  │  │  Public Subnet (10.0.1.0/24)           │ │ │
│  │  │                                         │ │ │
│  │  │  ┌──────────────────────────────────┐  │ │ │
│  │  │  │  EC2 Instance (t3.micro)        │  │ │ │
│  │  │  │  Ubuntu 22.04 LTS               │  │ │ │
│  │  │  │  Private IP: 10.0.1.100         │  │ │ │
│  │  │  │  Public IP: Elastic IP          │  │ │ │
│  │  │  │                                  │  │ │ │
│  │  │  │  ├─ Nginx (Phase 3)             │  │ │ │
│  │  │  │  ├─ Prometheus (Phase 4)        │  │ │ │
│  │  │  │  ├─ Grafana (Phase 4)           │  │ │ │
│  │  │  │  ├─ Loki (Phase 5)              │  │ │ │
│  │  │  │  └─ Node Exporter (Phase 4)     │  │ │ │
│  │  │  │                                  │  │ │ │
│  │  │  │  Root Volume: 20GB (encrypted)  │  │ │ │
│  │  │  └──────────────────────────────────┘  │ │ │
│  │  │                                         │ │ │
│  │  │  Security Group:                       │ │ │
│  │  │  ├─ Allow SSH (22)                    │ │ │
│  │  │  ├─ Allow HTTP (80)                   │ │ │
│  │  │  ├─ Allow HTTPS (443)                 │ │ │
│  │  │  ├─ Allow Prometheus (9090)           │ │ │
│  │  │  ├─ Allow Grafana (3000)              │ │ │
│  │  │  └─ Allow all outbound                │ │ │
│  │  │                                         │ │ │
│  │  │  UFW (Host Firewall):                 │ │ │
│  │  │  ├─ Allow SSH, HTTP, HTTPS           │ │ │
│  │  │  ├─ Allow Prometheus, Grafana        │ │ │
│  │  │  └─ Deny everything else              │ │ │
│  │  └─────────────────────────────────────────┘ │ │
│  │                                               │ │
│  │  Internet Gateway (0.0.0.0/0)               │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘

## Terraform Modules

### 1. Networking Module
**Location:** `modules/networking/`

**Resources Created:**
- VPC (10.0.0.0/16)
- Public Subnet (10.0.1.0/24)
- Internet Gateway
- Route Table
- Route Table Association

**Variables:**
- `environment`: Environment name
- `vpc_cidr`: VPC CIDR block
- `public_subnet_cidr`: Subnet CIDR

**Outputs:**
- `vpc_id`
- `public_subnet_id`
- `internet_gateway_id`

### 2. Security Module
**Location:** `modules/security/`

**Resources Created:**
- Security Group (stateful firewall)
- Inbound rules for: SSH, HTTP, HTTPS, Prometheus, Grafana
- Outbound rule (allow all)

**Variables:**
- `vpc_id`: VPC to attach to
- `environment`: Environment name
- `allowed_ssh_cidrs`: List of IPs allowed SSH

**Outputs:**
- `security_group_id`

### 3. Compute Module
**Location:** `modules/compute/`

**Resources Created:**
- EC2 Instance (Ubuntu 22.04)
- Elastic IP (static public IP)
- User Data script (system initialization)

**Variables:**
- `environment`: Environment name
- `instance_type`: EC2 type (t3.micro, t3.small, etc.)
- `subnet_id`: Subnet to launch in
- `security_group_id`: Security group to attach
- `key_name`: SSH key pair name
- `root_volume_size`: EBS volume size (GB)
- `internet_gateway_id`: For EIP dependency

**Outputs:**
- `instance_id`
- `public_ip`
- `private_ip`

**User Data Script Does:**
- System update & upgrade
- Install Docker, AWS CLI, tools
- Enable UFW firewall
- Harden SSH (disable root, passwords)
- Create directories for services
- Create systemd service templates

### 4. DNS Module
**Location:** `modules/dns/`

**Resources Created:**
- Route 53 A record (domain → Elastic IP)
- Optional: www subdomain

**Variables:**
- `domain_name`: Domain to create record for
- `elastic_ip`: IP to point to
- `create_www_record`: Create www subdomain

**Outputs:**
- `zone_id`: Route 53 hosted zone
- `a_record`: FQDN of created record

## State Management

### S3 Backend
Bucket: hng-terraform-state-ACCOUNT_ID
├── dev/
│   └── terraform.tfstate
├── staging/
│   └── terraform.tfstate
└── prod/
└── terraform.tfstate

**Features:**
- Versioning enabled (disaster recovery)
- Encryption enabled (AES-256)
- Public access blocked
- All sensitive values encrypted

### DynamoDB Locking
Table: hng-terraform-locks
├── Lock acquired when: terraform apply starts
├── Lock released when: terraform apply completes
└── Prevents: Simultaneous deployments

## Deployment Flow

Developer runs: terraform plan
├── Acquires lock (DynamoDB)
├── Loads state (S3)
├── Compares desired vs actual
└── Shows changes
Review plan
├── Check resources being created
├── Check security rules
└── Approve or reject
Developer runs: terraform apply
├── Acquires lock (DynamoDB)
├── Creates/updates resources
├── Saves state (S3)
└── Releases lock
Verification
├── SSH into instance
├── Check services
└── Run health checks


## Cost Structure

| Resource | Tier | Monthly Cost |
|----------|------|--------------|
| EC2 t3.micro | Free tier | $10 |
| EBS 20GB | Free tier | $2 |
| Elastic IP | Free (associated) | $0 |
| Data transfer | Variable | $1-5 |
| S3 (state) | Minimal | <$1 |
| DynamoDB (locking) | Minimal | <$1 |
| **Total** | | **~$15/month** |

**Note:** First 12 months, EC2 and EBS are free (AWS free tier).

## Network Connectivity

### Inbound Traffic
Internet → Route 53 (DNS lookup) → Elastic IP
↓
Security Group (allow 22, 80, 443, 9090, 3000)
↓
UFW (allow 22, 80, 443, 9090, 3000)
↓
EC2 Instance (Ubuntu)

### Outbound Traffic
EC2 Instance
↓
UFW (allow all outbound)
↓
Security Group (allow all outbound)
↓
Internet Gateway (0.0.0.0/0)
↓
Internet

Used for:
- apt-get updates
- DNS resolution
- NTP (time sync)
- Service downloads

## Security Layers

### Layer 1: AWS Account
- IAM users with minimal permissions
- MFA enabled (recommended)

### Layer 2: Network Level
- VPC isolation
- Security groups (stateful firewall)
- Private subnet option (not used here)

### Layer 3: Host Level
- UFW firewall
- SSH key-only auth
- Root login disabled
- Auto security updates

### Layer 4: Application Level
- TLS/HTTPS enforcement (Phase 3)
- Security headers (Phase 3)
- Rate limiting (Phase 3)

## Scaling Considerations

**Current:** Single EC2 instance, single AZ

**To Scale:**
1. **Multiple instances:** Use Auto Scaling Group
2. **Load balancing:** Use Application Load Balancer
3. **Database:** Add RDS
4. **Caching:** Add ElastiCache
5. **Multi-region:** Create stacks in different regions

Terraform modules are designed to be reusable for these scenarios.

## Disaster Recovery

### Backup Strategy

| Asset | Method | RTO | RPO |
|-------|--------|-----|-----|
| Code | GitHub | Instant | Real-time |
| State | S3 versioning | Minutes | Hourly |
| Config | User data script | 3 min | Deployment time |

### Recovery Procedures

**Instance Lost:**
```bash
cd environments/prod
terraform destroy -auto-approve
terraform apply -auto-approve
# 5 minutes to full recovery
```

**State Corrupted:**
```bash
# Restore from S3 versioning
aws s3api get-object \
  --bucket hng-terraform-state-ACCOUNT_ID \
  --key prod/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate

# Or rebuild state from AWS resources
terraform import aws_instance.web i-0123456789abcdef0
```

**SSH Key Lost:**
```bash
# Create new key in AWS
aws ec2 create-key-pair --key-name hng-infrastructure-2
# Update Terraform
# Redeploy
terraform apply -var="key_name=hng-infrastructure-2"
```

## Monitoring & Observability (Future Phases)

### Phase 4: Metrics
- Prometheus scrapes: CPU, memory, disk, Nginx
- Grafana dashboards: System health, requests
- Alerts: High CPU, low disk, service down

### Phase 5: Logging
- Loki collects: Nginx, auth, syslog
- Promtail ships: Logs → Loki
- Search: Find issues across logs

### Phase 6: CI/CD
- GitHub Actions validates: Terraform syntax
- GitHub Actions plans: Preview changes
- GitHub Actions applies: Deploy after approval

---

**Last Updated:** 2024-01-15  
**Architecture Version:** 1.0  
**Terraform Version:** 1.5.0+
