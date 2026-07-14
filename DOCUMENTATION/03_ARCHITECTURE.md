# Architecture: HNG Infrastructure

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub (Source Control)                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Repository: hng-infrastructure                      │   │
│  │  - Terraform code (IaC)                              │   │
│  │  - GitHub Actions workflows                          │   │
│  │  - Configuration files (tfvars)                      │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬──────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions (CI/CD Orchestration)            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  plan.yml       - Validates infrastructure changes  │   │
│  │  apply.yml      - Deploys infrastructure             │   │
│  │  destroy.yml    - Tears down infrastructure          │   │
│  │  OIDC Auth      - Temporary AWS credentials          │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬──────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                 AWS Account (us-east-1)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                 │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │        Public Subnet (10.0.1.0/24)          │   │   │
│  │  │  ┌─────────────────────────────────────┐    │   │   │
│  │  │  │   EC2 Instance (t3.micro)          │    │   │   │
│  │  │  │   Ubuntu 22.04 LTS                 │    │   │   │
│  │  │  │   ┌────────────────────────────┐   │    │   │   │
│  │  │  │   │  Services                  │   │    │   │   │
│  │  │  │   ├─ Nginx (443/80)            │   │    │   │   │
│  │  │  │   ├─ Prometheus (9090)         │   │    │   │   │
│  │  │  │   ├─ Grafana (3000)            │   │    │   │   │
│  │  │  │   ├─ Loki (3100)               │   │    │   │   │
│  │  │  │   ├─ Node Exporter (9100)      │   │    │   │   │
│  │  │  │   └─ Docker (containers)       │   │    │   │   │
│  │  │  │      ├─ Frontend (3001)        │   │    │   │   │
│  │  │  │      ├─ Backend API (8000)     │   │    │   │   │
│  │  │  │      ├─ Redis (6379)           │   │    │   │   │
│  │  │  │      └─ Worker                 │   │    │   │   │
│  │  │  └────────────────────────────────┘   │    │   │   │
│  │  │                                        │    │   │   │
│  │  │  Elastic IP: 100.25.222.228          │    │   │   │
│  │  └─────────────────────────────────────────┘    │   │   │
│  │                                                  │   │   │
│  │  Internet Gateway                              │   │   │
│  │  Route Table                                   │   │   │
│  │  Security Groups                               │   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  Route53 Hosted Zone                                    │
│  - infra.mosesekerin.name.ng (A record → EIP)          │
│  - www.infra.mosesekerin.name.ng (A record → EIP)      │
│                                                          │
│  S3 Bucket: hng-terraform-state-617163942982           │
│  - terraform.tfstate (encrypted)                        │
│  - terraform.tfstate.backup                             │
│                                                          │
│  IAM Role: github-actions-terraform                     │
│  - OIDC trust policy                                    │
│  - EC2, VPC, Route53, IAM permissions                   │
└─────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Networking Layer

#### VPC (Virtual Private Cloud)
- **CIDR:** 10.0.0.0/16
- **Purpose:** Isolated network environment
- **Components:**
  - 1 public subnet (10.0.1.0/24)
  - 1 Internet Gateway
  - 1 Route Table
  - 3 Network ACLs (implicit)

#### Public Subnet
- **CIDR:** 10.0.1.0/24
- **Route Table:** Routes 0.0.0.0/0 to Internet Gateway
- **Hosts:** EC2 instance only
- **Auto-assign Public IP:** Enabled via Elastic IP

#### Internet Gateway
- **Purpose:** Provides internet connectivity
- **Attached to:** VPC
- **Routes:** Routes public traffic to/from VPC

#### Elastic IP
- **Address:** 100.25.222.228
- **Association:** Permanently associated with EC2 instance
- **Purpose:** Static public IP for DNS, HTTPS certificates

#### Route Table
- **Rules:**
  - Destination: 0.0.0.0/0 → Target: Internet Gateway
  - Destination: 10.0.0.0/16 → Target: Local
- **Purpose:** Routes all outbound traffic to IGW, local traffic to VPC

#### Security Groups
- **Web Security Group (sg-0e6f10d9a1efb6794)**
  - **Ingress Rules:**
    - SSH (22/tcp): From 102.93.7.11/32 (hardcoded CIDR)
    - HTTP (80/tcp): From 0.0.0.0/0
    - HTTPS (443/tcp): From 0.0.0.0/0
    - Prometheus (9090/tcp): From 0.0.0.0/0
    - Grafana (3000/tcp): From 0.0.0.0/0
    - Loki (3100/tcp): From 0.0.0.0/0
    - Node Exporter (9100/tcp): From 0.0.0.0/0
  - **Egress Rules:**
    - All traffic to 0.0.0.0/0

---

### 2. Compute Layer

#### EC2 Instance
- **AMI:** Ubuntu 22.04 LTS (Canonical, latest)
- **Instance Type:** t3.micro (free tier eligible)
- **Subnet:** Public Subnet (10.0.1.0/24)
- **Root Volume:** 20GB gp3, encrypted
- **Key Pair:** hng-infrastructure.pem (SSH access)
- **IAM Role:** web-server role (SSM Parameter Store access)
- **Tags:** Environment=prod, Name=prod-web-server

#### IAM Role for EC2
- **Purpose:** Allows instance to access AWS services
- **Permissions:**
  - SSM ParameterStore read (for secrets)
  - CloudWatch logs write (monitoring)
- **Trust Policy:** EC2 service can assume role

#### User Data Script (Initialization)
Executed automatically on first boot:
- System updates and base packages
- Docker installation
- Nginx installation and initial config
- Certbot installation for SSL
- Prometheus binary installation
- Grafana binary installation
- Loki binary installation
- Promtail configuration
- Git clone of microservices repo
- Docker Compose up for application stack

---

### 3. Storage Layer

#### S3 Bucket: hng-terraform-state-617163942982
- **Purpose:** Remote state storage
- **Encryption:** AES-256 (default)
- **Versioning:** Enabled
- **Key Path:** prod/terraform.tfstate
- **Access:** Only via OIDC-authenticated GitHub Actions
- **Backup:** Automatic backups during destroy workflow

#### EBS Volume (Root)
- **Size:** 20 GB
- **Type:** gp3 (General Purpose)
- **Encryption:** Enabled
- **IOPS:** Default (3000)
- **Throughput:** Default (125 MB/s)
- **Delete on Termination:** True

---

### 4. DNS Layer

#### Route53 Hosted Zone
- **Zone ID:** Z08555352HXVFFAQTK8F0
- **Parent Domain:** mosesekerin.name.ng
- **Record Types:**
  - A Record: infra.mosesekerin.name.ng → 100.25.222.228
  - A Record: www.infra.mosesekerin.name.ng → 100.25.222.228

#### DNS Resolution
- **Query Flow:** User → Route53 → 100.25.222.228 (Elastic IP)
- **TTL:** Default (300 seconds)
- **Resolution Type:** A record (IPv4)

---

### 5. Web/Reverse Proxy Layer

#### Nginx Server
- **Port:** 443 (HTTPS), 80 (HTTP redirect)
- **Process:** nginx (master/worker processes)
- **Upstream:** Connections to frontend microapp (127.0.0.1:3001)
- **Configuration File:** /etc/nginx/nginx.conf
- **Log Format:** Structured with timestamps, response times
- **Features:**
  - Gzip compression
  - Rate limiting (general: 30 req/s, api: 10 req/s)
  - HSTS header
  - Security headers

#### TLS/SSL Configuration
- **Certificate Provider:** Let's Encrypt
- **Certificate Path:** /etc/letsencrypt/live/infra.mosesekerin.name.ng/
- **Renewal:** Automatic via certbot cron
- **Protocol:** TLS 1.2 and 1.3
- **Ciphers:** ECDHE-ECDSA-AES128-GCM-SHA256, ECDHE-RSA-AES128-GCM-SHA256
- **HSTS:** max-age=31536000, includeSubDomains

#### Routing Rules
- **/** → Proxies to frontend microapp (127.0.0.1:3001)
- **/health** → Returns "OK\n" (internal health check)
- **/metrics** → Returns 404 (disabled)
- **/** (all others) → Returns 404

---

### 6. Monitoring & Observability Layer

#### Prometheus
- **Port:** 9090
- **Binary Location:** /opt/prometheus/
- **Process:** prometheus (scrapes targets every 15s default)
- **Scrape Targets:**
  - Node Exporter (127.0.0.1:9100)
  - Prometheus self-monitoring
- **Storage:** Time-series database (tsdb)
- **Retention:** Default (15 days)
- **Data Flow:** Prometheus pulls metrics from exporters

#### Node Exporter
- **Port:** 9100
- **Binary Location:** /opt/node_exporter/
- **Metrics Exported:**
  - System CPU, memory, disk, network
  - File descriptors
  - Load average
  - Uptime
- **Scrape Interval:** Every 15 seconds (Prometheus configured)

#### Grafana
- **Port:** 3000
- **Service:** grafana-server
- **Data Source:** Prometheus (configured)
- **Dashboards:** Auto-provisioned
- **Default Credentials:** admin/admin
- **Authentication:** Local admin user
- **Data Flow:** Grafana queries Prometheus for metrics

#### Prometheus Alerts
- **Rules File:** /opt/prometheus/alert_rules.yml
- **Alert Examples:**
  - High CPU usage
  - High memory usage
  - Disk space low
  - Service down
- **Evaluation Interval:** 15 seconds
- **Trigger:** When threshold exceeded

---

### 7. Logging Layer

#### Loki
- **Port:** 3100
- **Purpose:** Log aggregation service
- **Index Strategy:** Label indexing (fast)
- **Storage:** Local filesystem
- **Data Flow:** Receives logs from Promtail

#### Promtail
- **Purpose:** Log shipper
- **Configuration:** /etc/promtail/config.yml
- **Log Sources:**
  - Nginx access logs
  - System logs
  - Application logs
- **Labels:** Added for filtering (job, filename, host)
- **Data Flow:** Tails files → Promtail → Loki

#### Structured Logging
- **Format:** `$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" request_time=$request_time upstreamtime=$upstream_response_time`
- **Purpose:** Machine-parseable logs for aggregation
- **Log Files:**
  - /var/log/nginx/access.log (all requests)
  - /var/log/nginx/root.log (root endpoint)
  - /var/log/nginx/404.log (not found)
  - /var/log/nginx/microapp_frontend.log (frontend proxy)

---

### 8. Container/Application Layer

#### Docker Compose Stack
- **Location:** /home/ubuntu/micro-service-app/job-queue-microservices/
- **Orchestration:** Docker Compose v2
- **Network:** job-queue-microservices default network (internal)

#### Frontend Service
- **Image:** microapp-frontend (custom image)
- **Port:** 3000 (internal) → 3001 (host)
- **Environment:** Frontend React/Vue application
- **Health Check:** HTTP endpoint polling
- **Restart Policy:** Unless-stopped
- **Network Mode:** Connected to microapp network (internal)
- **Exposed:** Via Nginx reverse proxy only

#### Backend API Service
- **Image:** microapp-api (FastAPI)
- **Port:** 8000 (internal, not exposed to host)
- **Environment:** REDIS_PASSWORD from AWS Parameter Store
- **Health Check:** HTTP endpoint
- **Restart Policy:** Unless-stopped
- **Network Mode:** Connected to microapp network (internal)
- **Exposed:** Not exposed publicly (frontend access only)

#### Redis Service
- **Image:** redis:7
- **Port:** 6379 (internal, not exposed to host)
- **Purpose:** Caching and job queue
- **Health Check:** Redis ping
- **Restart Policy:** Unless-stopped
- **Network Mode:** Connected to microapp network (internal)
- **Authentication:** Password from AWS Parameter Store
- **Exposed:** Not exposed publicly

#### Worker Service
- **Image:** microapp-worker (custom image)
- **Purpose:** Background job processing
- **Network Mode:** Connected to microapp network (internal)
- **Health Check:** Configured
- **Restart Policy:** Unless-stopped
- **Exposed:** Not exposed publicly

#### Docker Network
- **Name:** job-queue-microservices (auto-created)
- **Type:** Bridge
- **IPAM:** Default (172.17.0.0/16)
- **Scope:** Local to host
- **Service Discovery:** Docker DNS (service names resolve)
- **Isolation:** Internal only, not accessible from host directly

---

### 9. IAM & Security Layer

#### GitHub OIDC Provider
- **Provider ARN:** arn:aws:iam::617163942982:oidc-provider/token.actions.githubusercontent.com
- **Thumbprint:** GitHub's certificate thumbprint
- **Trust:** GitHub Actions can assume role without stored credentials

#### IAM Role: github-actions-terraform
- **ARN:** arn:aws:iam::617163942982:role/github-actions-terraform
- **Trust Policy:** OIDC trust for GitHub
- **Permissions:** Inline policy "terraform-permissions"
  - S3: List, Get, Put, Delete (state bucket)
  - DynamoDB: Put, Get, Delete (removed locks)
  - EC2: Full access (*)
  - VPC: Full access (*)
  - Route53: Full access (*)
  - IAM: Full access (*)

#### SSH Key Management
- **Local Path:** ~/.ssh/hng-infrastructure.pem
- **Key Pair:** hng-infrastructure (in AWS)
- **Access:** EC2 via SSH port 22
- **Authentication:** Private key only (no password auth)

#### Secrets Management
- **Location:** AWS Parameter Store
- **Path:** /microapp/prod/redis_password
- **Access:** EC2 via IAM role
- **Retrieval:** During user data script execution
- **Usage:** Redis authentication, environment file creation

---

### 10. Terraform IaC Layer

#### Module Structure
```
modules/
├── networking/
│   ├── main.tf (VPC, Subnet, IGW, Route Table)
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf
├── security/
│   ├── main.tf (Security Groups, Rules)
│   ├── variables.tf
│   └── outputs.tf
├── compute/
│   ├── main.tf (EC2, EIP, IAM)
│   ├── iam.tf (IAM roles and policies)
│   ├── user_data.sh (initialization script)
│   ├── variables.tf
│   └── outputs.tf
├── dns/
│   ├── main.tf (Route53 records)
│   ├── variables.tf
│   └── outputs.tf
├── monitoring/
│   ├── main.tf (local files for config)
│   ├── templates/ (Prometheus, Grafana config)
│   ├── variables.tf
│   └── outputs.tf
└── templates/
    └── (Nginx, Prometheus, Grafana configs)
```

#### Environment Configuration
```
environments/prod/
├── main.tf (module calls)
├── variables.tf (variable definitions)
├── outputs.tf (output values)
├── terraform.tfvars (local, gitignored)
├── example.tfvars (git committed, CI/CD uses)
└── .terraform/ (local state, gitignored)
```

#### Remote Backend
```hcl
terraform {
  backend "s3" {
    bucket         = "hng-terraform-state-617163942982"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = (removed)
  }
}
```

---

### 11. CI/CD Pipeline Architecture

#### GitHub Actions Workflows

**plan.yml (Pull Request Validation)**
```
Event: pull_request on environments/prod/** or modules/**
         ↓
    Checkout code
         ↓
    Configure AWS Credentials (OIDC)
         ↓
    Setup Terraform
         ↓
    Terraform Format Check
         ↓
    Terraform Init
         ↓
    Terraform Validate
         ↓
    Terraform Plan (-lock=false)
         ↓
    Convert Plan to Text (terraform show)
         ↓
    Comment PR with Plan Output
         ↓
    Fail if Plan Failed
         ↓
    Output: PR comment visible
```

**apply.yml (Automated Deployment)**
```
Event: push to main on environments/prod/** or modules/**
       (excluding example.tfvars)
         ↓
    Checkout code
         ↓
    Configure AWS Credentials (OIDC)
         ↓
    Setup Terraform
         ↓
    Terraform Init
         ↓
    Terraform Plan (-lock=false)
         ↓
    ⏸️  APPROVAL GATE (production environment)
         ↓
    Terraform Apply (-auto-approve -lock=false)
         ↓
    Get Outputs (extract IP, domain)
         ↓
    Create Deployment Summary
         ↓
    Output: Infrastructure deployed
```

**destroy.yml (Manual Cleanup)**
```
Event: workflow_dispatch manual trigger
         ↓
    Verify Confirmation ("destroy-infrastructure")
         ↓
    Checkout code
         ↓
    Configure AWS Credentials (OIDC)
         ↓
    Setup Terraform
         ↓
    Terraform Init
         ↓
    Backup State to S3
         ↓
    ⏸️  APPROVAL GATE (production environment)
         ↓
    Terraform Destroy (-var-file=example.tfvars)
         ↓
    Output: Infrastructure destroyed
```

---

## Data Flow Diagrams

### User Request Flow
```
User Browser
    ↓ HTTPS GET /
    ↓
DNS Resolution (Route53)
    ↓ 100.25.222.228
    ↓
Nginx (Port 443)
    ↓
Reverse Proxy to Frontend
    ↓ http://127.0.0.1:3001/
    ↓
Frontend Container (React/Vue)
    ↓ HTML/JS Response
    ↓
Browser renders UI
    ↓ (User interacts)
    ↓
Frontend makes API call
    ↓ http://backend:8000/api/
    ↓
Backend Container (FastAPI)
    ↓ Query Redis (127.0.0.1:6379)
    ↓
Redis Cache
    ↓ Response
    ↓
API Response to Frontend
    ↓
Frontend updates UI
```

### Metrics Collection Flow
```
System Metrics Generated
    ↓
Node Exporter
    ↓ Exposes metrics on port 9100
    ↓
Prometheus Scrapes (every 15s)
    ↓ http://127.0.0.1:9100/metrics
    ↓
Prometheus Time-Series DB
    ↓
Grafana Queries (on demand)
    ↓ HTTP queries to Prometheus
    ↓
Grafana Dashboard Renders
    ↓ User views at :3000
```

### Logs Collection Flow
```
Application Logs
Nginx Access Logs
System Syslog
    ↓ (Multiple sources)
    ↓
Promtail (Log Shipper)
    ↓ Tails files, adds labels
    ↓
HTTP POST to Loki
    ↓
Loki (Log Aggregator)
    ↓ Stores with labels
    ↓
User Queries via Loki API
    ↓ loki/api/v1/query
    ↓ Returns logs
```

### Infrastructure Deployment Flow
```
Developer Writes Terraform
    ↓ git push origin feature-branch
    ↓
GitHub Detects PR
    ↓ Files changed in environments/prod/
    ↓
plan.yml Workflow Triggers
    ↓
Terraform Plan Runs
    ↓ (No changes to AWS)
    ↓
Output → PR Comment
    ↓
Developer Reviews
    ↓ Approves and Merges PR
    ↓
apply.yml Workflow Triggers
    ↓
Terraform Init (load state from S3)
    ↓
Terraform Plan (again, final check)
    ↓
⏸️  Wait for Approval
    ↓
Terraform Apply (makes changes)
    ↓
AWS Resources Created/Updated
    ↓
Outputs Extracted
    ↓
Deployment Summary Posted
    ↓
Infrastructure Ready
```

---

## Security Boundaries

### 1. Public Layer
- Accessible from internet
- Nginx (port 443, 80)
- DNS (Route53)
- Everything else blocked by security group

### 2. Host Layer
- EC2 instance only accessible via:
  - SSH (port 22) from specific CIDR
  - Services listening on localhost
- Services not publicly exposed:
  - Prometheus (9090)
  - Grafana (3000)
  - Loki (3100)
  - Node Exporter (9100)

### 3. Container Network
- Internal Docker network (172.17.0.0/16)
- Services communicate via service names
- No external access
- Backend API internal only
- Redis internal only

### 4. Storage Layer
- S3 state bucket encrypted
- Encrypted EBS volume
- SSH keys never stored in git
- Secrets in Parameter Store (not in code)

---

## Deployment Topology

### Production Environment (us-east-1)
- Single availability zone (1a)
- Single EC2 instance (could scale to Multi-AZ)
- Single NAT/IGW point (single point of failure for now)
- RTO/RPO: Full rebuild from Terraform (~5 minutes)

### Scaling Considerations
- Instance Type: t3.micro (can upgrade to larger)
- Disk: 20GB (can increase)
- Database: Would require RDS (currently containerized)
- Load Balancing: Would require ALB/NLB (currently single instance)
- Backup Strategy: State file backup only (not application data)

---

## Critical Architectural Properties

### Reproducibility
- ✅ Destroy and recreate anytime
- ✅ Identical configuration each time
- ✅ Version controlled (git history)

### Auditability
- ✅ Every infrastructure change in git
- ✅ Every deployment logged in GitHub Actions
- ✅ CloudTrail logs in AWS

### Security
- ✅ No credentials in code
- ✅ OIDC temporary credentials
- ✅ Encrypted state file
- ✅ SSH keys only (no passwords)
- ✅ Security groups restrict access

### Observability
- ✅ Metrics collection (Prometheus)
- ✅ Dashboards (Grafana)
- ✅ Log aggregation (Loki)
- ✅ Structured logging

### Maintainability
- ✅ Modular Terraform code
- ✅ Automation (no manual steps)
- ✅ Clear separation of concerns
- ✅ Infrastructure versioned
