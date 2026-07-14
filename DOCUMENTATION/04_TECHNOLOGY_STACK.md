# Technology Stack: HNG Infrastructure

## Cloud Infrastructure

### AWS
- **Account:** 617163942982 (us-east-1 region)
- **Services Used:**
  - **EC2** - Compute instances
  - **VPC** - Virtual networking
  - **Route53** - DNS management
  - **S3** - State file storage
  - **IAM** - Identity and access management
  - **EIP** - Elastic IP (static public IP)
  - **EBS** - Block storage for EC2
  - **Parameter Store** - Secrets management
  - **CloudTrail** - Audit logging (implicit)

**Why AWS?**
- Industry standard for infrastructure
- Free tier availability (t3.micro)
- Extensive service ecosystem
- OIDC support for GitHub Actions
- Well-documented for DevOps

---

## Infrastructure as Code

### Terraform
- **Version:** 1.5.0 (specified in workflows)
- **Language:** HCL2
- **State Backend:** S3 (remote)
- **Lock Strategy:** No DynamoDB (solo developer)

**Components:**
- Modular structure (networking, compute, security, dns, monitoring)
- Separate environment configurations (prod)
- Variable management (terraform.tfvars + example.tfvars)
- Output extraction for CI/CD

**Why Terraform?**
- Declarative IaC (describe desired state)
- Multi-cloud support (AWS, Azure, GCP)
- State management built-in
- Large community and ecosystem
- Better than CloudFormation (more portable)
- HCL is readable and maintainable

**Alternative Considered:** CloudFormation
- **Not chosen because:** AWS-specific, JSON/YAML verbose, less portable

---

## CI/CD & Automation

### GitHub Actions
- **Version:** Latest
- **Workflows:** plan.yml, apply.yml, destroy.yml
- **Language:** YAML
- **Authentication:** OIDC (no stored credentials)
- **Approval Gates:** Yes (production environment)

**Workflow Components:**
- Checkout code
- AWS credential configuration (OIDC)
- Terraform operations
- Output extraction
- PR comments
- Approval gates

**Why GitHub Actions?**
- Native GitHub integration
- No external CI/CD tool needed
- OIDC support (secure credentials)
- Free for public repos
- Sufficient for single-developer team

**Alternative Considered:** GitLab CI, Jenkins, CircleCI
- **Not chosen because:** GitHub repo already in GitHub, GitHub Actions fully integrated

### OIDC (OpenID Connect)
- **Purpose:** Secure AWS authentication without storing credentials
- **Implementation:** GitHub OIDC Provider + IAM Role Trust Policy
- **Token Lifetime:** ~1 hour
- **Credential Type:** Temporary STS tokens

**Why OIDC?**
- Zero stored AWS credentials
- Industry security best practice
- Automatic token rotation
- Audit trail of all access
- No risk of credential leakage

**Alternative Considered:** AWS Access Keys
- **Not chosen because:** Long-lived credentials pose security risk, best practice is OIDC

---

## Containerization

### Docker
- **Version:** Latest (installed via apt)
- **Orchestration:** Docker Compose v2
- **Network Mode:** Default bridge (internal)
- **Registry:** Docker Hub (public images for base layers)

**Services:**
- Frontend (React/Vue application)
- Backend API (FastAPI)
- Redis (caching)
- Worker (job processing)

**Why Docker?**
- Application portability
- Dependency isolation
- Reproducible environments
- Microservices separation
- Easy deployment and scaling

**Alternative Considered:** Kubernetes, systemd services
- **Not chosen because:** Over-engineered for single instance, Docker Compose sufficient

### Docker Compose
- **Version:** V2 (compose-v2 package)
- **Configuration:** docker-compose.yml
- **Health Checks:** Configured for all services
- **Restart Policy:** Unless-stopped (auto-restart)

**Why Docker Compose?**
- Multi-container orchestration
- Simple configuration
- Service discovery
- Network management
- Health checks built-in

---

## Web Server & Reverse Proxy

### Nginx
- **Version:** 1.18 (from Ubuntu 22.04 repo)
- **Port:** 443 (HTTPS), 80 (HTTP redirect)
- **Features:**
  - Gzip compression
  - Rate limiting
  - Structured logging
  - Reverse proxy

**Configuration:**
- SSL/TLS termination
- Frontend reverse proxy (to http://127.0.0.1:3001)
- Health check endpoint
- Security headers

**Why Nginx?**
- High performance
- Lightweight
- Reverse proxy capabilities
- SSL/TLS support
- Mature and well-documented

**Alternative Considered:** Apache httpd, Caddy
- **Not chosen because:** Nginx is standard, lighter weight, excellent performance

---

## SSL/TLS Certificate Management

### Let's Encrypt
- **Certificate Authority:** Free, automated
- **Certificate:** wildcard and base domain
- **Renewal:** Automatic via certbot cron
- **Renewal Hook:** Nginx reload on renewal

**Implementation:**
- Certbot tool for certificate management
- Renewal every 90 days (automated)
- Hook to reload Nginx on renewal

**Why Let's Encrypt?**
- Free SSL certificates
- Fully automated renewal
- Industry standard
- Zero cost

**Alternative Considered:** Self-signed, AWS ACM
- **Not chosen because:** Self-signed fails trust validation, ACM requires additional AWS setup

### Certbot
- **Purpose:** Let's Encrypt client
- **Plugin:** Nginx (handles verification)
- **Path:** /usr/local/bin/setup-ssl.sh (wrapper script)
- **Renewal Hook:** /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh

**Why Certbot?**
- Official Let's Encrypt client
- Nginx plugin integration
- Automatic renewal support

---

## Monitoring & Observability

### Prometheus
- **Version:** Latest binary (prometheus-X.X.X.linux-amd64)
- **Port:** 9090
- **Scrape Interval:** 15 seconds
- **Retention:** 15 days (default)
- **Data:** Time-series metrics

**Scrapers Configured:**
- Node Exporter (9100)
- Prometheus self-monitoring

**Alert Rules:** Configured (CPU, memory, disk, service down)

**Why Prometheus?**
- Industry standard metrics collection
- Time-series database optimized for metrics
- Efficient storage
- Powerful query language (PromQL)
- Grafana integration

**Alternative Considered:** DataDog, New Relic, CloudWatch
- **Not chosen because:** Self-hosted + free tier sufficient, control over data

### Grafana
- **Version:** 10.2.0 (binary install)
- **Port:** 3000
- **Data Source:** Prometheus
- **Dashboards:** Auto-provisioned
- **Default User:** admin/admin

**Features:**
- Real-time dashboard visualization
- Auto-generated dashboards
- Alert rule creation
- Multi-source data support

**Why Grafana?**
- Best-in-class visualization
- Easy dashboard creation
- Prometheus integration
- Open-source
- Large community

**Alternative Considered:** Datadog, Splunk UI
- **Not chosen because:** Self-hosted + free, better for Prometheus data

### Node Exporter
- **Version:** Latest binary (node_exporter-X.X.X.linux-amd64)
- **Port:** 9100
- **Metrics:** System CPU, memory, disk, network, load

**Purpose:** Export system-level metrics to Prometheus

**Why Node Exporter?**
- Official Prometheus system metrics exporter
- Comprehensive system data
- Low overhead
- Standard tool for infrastructure monitoring

---

## Logging & Log Aggregation

### Loki
- **Version:** Latest (binary install)
- **Port:** 3100
- **Purpose:** Log aggregation and storage
- **Index Strategy:** Label indexing (fast queries)

**Why Loki?**
- Lightweight log aggregation
- Label-based indexing (efficient)
- Prometheus-compatible
- Grafana integration
- Low storage overhead

**Alternative Considered:** ELK Stack (Elasticsearch), Splunk
- **Not chosen because:** Loki is lighter, label-based indexing sufficient, lower cost

### Promtail
- **Version:** Latest (binary install)
- **Purpose:** Log shipper
- **Sources:**
  - Nginx access logs
  - System syslog
  - Docker container logs

**Why Promtail?**
- Official Loki log shipper
- Lightweight
- Configuration management
- Multi-source support

**Alternative Considered:** Filebeat, Logstash
- **Not chosen because:** Promtail designed for Loki, lighter weight

---

## Operating System

### Ubuntu 22.04 LTS
- **Distribution:** Canonical-maintained
- **AMI:** Latest in region (queried dynamically)
- **LTS:** Long Term Support (5 years)
- **Base Packages:**
  - apt (package manager)
  - curl, wget (download tools)
  - git (version control)
  - vim (text editor)
  - htop (system monitoring)
  - jq (JSON processing)

**Why Ubuntu 22.04?**
- LTS support (stability)
- Large community
- Well-supported in AWS
- Canonical updates
- Free tier eligible

**Alternative Considered:** Amazon Linux 2, Debian
- **Not chosen because:** Ubuntu has better support ecosystem, more common in DevOps

---

## Programming Languages & Frameworks

### Bash
- **Purpose:** User data script, initialization
- **Script:** modules/compute/user_data.sh
- **Features:** 
  - System commands
  - Variable substitution
  - Conditional logic
  - Service management

**Why Bash?**
- AWS user data scripts use Bash
- System-level scripting
- Available on all Linux systems

### HCL (HashiCorp Configuration Language)
- **Purpose:** Terraform configuration
- **Syntax:** Declarative, JSON-compatible
- **Version:** HCL2 (modern)

**Why HCL?**
- Terraform native language
- Readable syntax
- Powerful expressions

### YAML
- **Purpose:** GitHub Actions workflows, Docker Compose
- **Purpose:** Configuration files
- **Version:** 1.2 (standard)

**Why YAML?**
- Human-readable
- GitHub Actions standard
- Docker Compose standard

---

## Source Control

### Git
- **Hosting:** GitHub (https://github.com/mosesekerin/hng-infrastructure)
- **Access:** SSH via key pair
- **Branching:** main + feature branches
- **Tags:** phase-1, phase-3, phase-4, phase-5, phase-6

**Why Git?**
- Industry standard VCS
- GitHub integration
- Full history and rollback capability
- Branching for feature development

---

## Secrets Management

### AWS Parameter Store
- **Usage:** Redis password storage
- **Path:** /microapp/prod/redis_password
- **Access:** EC2 via IAM role
- **Encryption:** Default (KMS)

**Why Parameter Store?**
- Built into AWS
- No external service needed
- IAM integration
- Automatic encryption

**Alternative Considered:** Secrets Manager, HashiCorp Vault
- **Not chosen because:** Parameter Store sufficient, already in AWS, no extra cost

---

## State Management

### S3 Backend
- **Bucket:** hng-terraform-state-617163942982
- **Key:** prod/terraform.tfstate
- **Encryption:** AES-256
- **Versioning:** Enabled
- **Access:** OIDC-authenticated GitHub Actions only

**Why S3?**
- Terraform native backend
- Encrypted storage
- Backup capability
- Cost-effective

**Alternative Considered:** Terraform Cloud, Consul, etcd
- **Not chosen because:** S3 sufficient for solo developer, no external dependency

---

## Security Tools

### UFW (Uncomplicated Firewall)
- **Purpose:** Host-level firewall
- **Policy:** Default deny incoming, allow outgoing
- **Enabled Ports:** SSH (22), HTTP (80), HTTPS (443), Monitoring ports
- **Status:** Enabled on startup

**Why UFW?**
- Simple firewall configuration
- Built into Ubuntu
- Host-level security layer

### OpenSSH
- **Purpose:** Secure shell access
- **Authentication:** Key-based only (no passwords)
- **Port:** 22
- **Configuration:**
  - PermitRootLogin: no
  - PasswordAuthentication: no
  - PubkeyAuthentication: yes

**Why OpenSSH?**
- Industry standard
- Secure key-based authentication
- Well-understood security model

---

## Development Tools

### Vim
- **Purpose:** Text editor
- **Installed:** For manual configuration if needed

### htop
- **Purpose:** System monitoring CLI
- **Installed:** For troubleshooting

### jq
- **Purpose:** JSON processing
- **Installed:** For parsing JSON in scripts

---

## Summary: Technology Decisions Matrix

| Category | Choice | Why | Alternatives |
|----------|--------|-----|--------------|
| Cloud | AWS | Industry standard, free tier, OIDC support | Azure, GCP |
| IaC | Terraform | Declarative, portable, mature | CloudFormation, Pulumi |
| CI/CD | GitHub Actions | Native GitHub, OIDC, free | GitLab CI, Jenkins |
| Auth | OIDC | Zero credentials, secure, temporary tokens | Access Keys, STS |
| Containers | Docker + Compose | Lightweight, portable, microservices | Kubernetes, systemd |
| Web Server | Nginx | High performance, reverse proxy | Apache, Caddy |
| SSL | Let's Encrypt | Free, automated renewal | Self-signed, ACM |
| Monitoring | Prometheus + Grafana | Industry standard, efficient, free | DataDog, New Relic |
| Logging | Loki + Promtail | Lightweight, label-indexed, Grafana integration | ELK, Splunk |
| OS | Ubuntu 22.04 LTS | LTS support, large community, AWS-friendly | Amazon Linux 2, Debian |
| Secrets | Parameter Store | AWS native, IAM integrated, encrypted | Secrets Manager, Vault |
| State | S3 Backend | Terraform native, encrypted, versioned | Terraform Cloud, Consul |

---

## Technology Stack Summary

**Total Distinct Technologies:** 20+
**Languages:** Bash, HCL, YAML
**Infrastructure:** AWS (VPC, EC2, EIP, Route53, S3, IAM, Parameter Store)
**IaC:** Terraform 1.5.0
**CI/CD:** GitHub Actions with OIDC
**Containers:** Docker + Docker Compose
**Web:** Nginx 1.18 + Let's Encrypt
**Monitoring:** Prometheus + Grafana
**Logging:** Loki + Promtail
**OS:** Ubuntu 22.04 LTS
**Security:** UFW, OpenSSH, OIDC, Parameter Store

**All technologies chosen for:** production-readiness, industry standards, learning value, cost-effectiveness, and security.
