# Features & Capabilities: HNG Infrastructure

## Infrastructure Capabilities

### 1. Infrastructure as Code

**What You Can Do:**
- Declare complete infrastructure in code
- Version control all infrastructure changes (git history)
- Reproduce infrastructure anytime (destroy and recreate)
- Deploy to multiple environments (dev, staging, prod)
- Collaborate on infrastructure changes via git

**How to Use:**
```bash
# View current infrastructure
terraform show

# Propose changes (no AWS modifications)
terraform plan -var-file=example.tfvars

# Apply changes (actually create/modify resources)
terraform apply -var-file=example.tfvars

# Destroy everything (complete cleanup)
terraform destroy -var-file=example.tfvars
```

**Capabilities:**
- ✅ Create VPC with custom CIDR
- ✅ Create subnets in multiple AZs (code supports this)
- ✅ Create security groups with custom rules
- ✅ Launch EC2 instances with custom configuration
- ✅ Assign static IP via Elastic IP
- ✅ Configure DNS records in Route53
- ✅ Create IAM roles and policies
- ✅ Configure EC2 initialization scripts

---

### 2. Automated Deployments

**What You Can Do:**
- Deploy infrastructure via GitHub Actions (no manual commands)
- Plan changes in pull requests (peer review)
- Require approval before production changes
- Automatic rollback capability (previous state)
- Full audit trail of all deployments

**How to Use:**
```bash
# 1. Create feature branch
git checkout -b feature/add-monitoring

# 2. Make changes to Terraform
vim environments/prod/main.tf

# 3. Push to GitHub
git push origin feature/add-monitoring

# 4. Open Pull Request
# GitHub automatically runs: terraform plan

# 5. Review the plan in PR comment
# (See exactly what will change)

# 6. Approve and merge
# GitHub automatically runs: terraform apply

# 7. Monitor deployment
# GitHub Actions UI shows progress
```

**Capabilities:**
- ✅ Validate Terraform syntax on PR
- ✅ Show infrastructure changes in PR comments
- ✅ Require approval before applying
- ✅ Block PRs with syntax errors
- ✅ Automatic deployment on merge
- ✅ Audit trail of who approved what
- ✅ Rollback by reverting commit

---

### 3. HTTPS & Security

**What You Can Do:**
- Serve all traffic over HTTPS with valid certificate
- Automatic SSL certificate renewal (no manual intervention)
- Security headers configured (HSTS, CSP, etc.)
- HTTP redirected to HTTPS
- TLS 1.2 and 1.3 supported

**Live Endpoints:**
- `https://infra.mosesekerin.name.ng/` - Root page
- `https://infra.mosesekerin.name.ng/api` - HNG API endpoint
- `https://infra.mosesekerin.name.ng/health` - Health check
- `https://infra.mosesekerin.name.ng/app` - Frontend application

**Certificate Details:**
- Issuer: Let's Encrypt
- Validity: 90 days (auto-renewed 30 days before expiry)
- Domains: infra.mosesekerin.name.ng
- Next Renewal: Automatic

**Security Headers:**
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer-when-downgrade
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

---

### 4. Monitoring Stack

**What You Can Do:**
- Collect system metrics (CPU, memory, disk, network)
- Store metrics in time-series database
- Create custom dashboards
- Query metrics with PromQL
- Set up alert rules

**How to Access:**
- **Prometheus:** `http://100.25.222.228:9090`
  - Raw metrics interface
  - Query PromQL
  - View scrape targets and alerts
  - Estimate storage usage
  
- **Grafana:** `http://100.25.222.228:3000`
  - Login: admin/admin
  - View auto-provisioned dashboards
  - Create custom dashboards
  - Set up notifications

**Metrics Collected:**
- **System Metrics:**
  - CPU: Usage percentage, load average
  - Memory: Used, available, cached
  - Disk: Used space, I/O operations
  - Network: Bytes sent/received, packets

- **Service Metrics:**
  - Nginx: Requests per second, response times
  - Uptime: System uptime, boot time

**Sample Queries (PromQL):**
```promql
# CPU usage percentage
node_cpu_seconds_total

# Available memory
node_memory_MemAvailable_bytes

# Disk usage
node_filesystem_avail_bytes

# System uptime
node_time_seconds
```

**Alert Rules Configured:**
- High CPU usage (>80%)
- Low available memory (<20%)
- Disk space low (<10%)
- Service down (no heartbeat)

---

### 5. Logging Stack

**What You Can Do:**
- Collect logs from multiple sources
- Query logs by labels (job, hostname, level)
- Search log history
- Track application events
- Troubleshoot issues via logs

**How to Access:**
- **Loki API:** `http://100.25.222.228:3100/loki/api/v1/`
  - List log labels
  - Query logs via API
  - Programmatic access

- **Grafana Logs:** `http://100.25.222.228:3000`
  - Integrated in Grafana
  - Query with Loki language
  - View logs alongside metrics

**Log Sources:**
- Nginx access logs (all HTTP requests)
- Application logs (from containers)
- System logs (kernel, services)

**Sample Queries:**
```
# All Nginx logs
{job="nginx"}

# Errors only
{job="nginx", level="error"}

# Specific endpoint
{job="nginx"} | "GET /api"

# Response time > 1 second
{job="nginx"} | json | request_time > "1"
```

**Log Retention:**
- Loki default: 24 hours
- Older logs: Can be extended via configuration

---

### 6. Container Orchestration

**What You Can Do:**
- Run multi-container application stack
- Automatic health checks and restart
- Service discovery between containers
- Environment variable management
- Scaled deployments

**Application Stack:**
1. **Frontend** (port 3001)
   - React/Vue application
   - Serves UI to users
   - Talks to backend API

2. **Backend API** (port 8000, internal only)
   - FastAPI application
   - Processes requests
   - Queries Redis cache

3. **Redis** (port 6379, internal only)
   - In-memory data store
   - Job queue
   - Cache layer

4. **Worker** (background service)
   - Job processor
   - Handles long-running tasks
   - Communicates via Redis

**How to Manage:**
```bash
# SSH to instance
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs from container
docker logs job-queue-microservices-frontend-1

# Restart container
docker compose -f /path/to/docker-compose.yml restart frontend

# Scale a service
docker compose up -d --scale worker=3
```

**Health Checks:**
- Frontend: HTTP GET / (200 OK)
- Backend: HTTP GET /health
- Redis: Redis ping
- Worker: Process alive check

All services configured with:
- `restart: unless-stopped`
- Health check with interval
- Auto-restart on failure

---

### 7. DNS Management

**What You Can Do:**
- Map domain name to infrastructure
- Point subdomains to resources
- Update DNS via Terraform
- TTL management
- Multi-region routing (future)

**Current DNS Records:**
```
Domain: infra.mosesekerin.name.ng
Type: A
Value: 100.25.222.228
TTL: 300 seconds
```

**How to Update:**
```hcl
# In Terraform
resource "aws_route53_record" "example" {
  zone_id = var.hosted_zone_id
  name    = "example.infra.mosesekerin.name.ng"
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}
```

---

### 8. Application Deployment

**What You Can Do:**
- Deploy microservices application
- Automatic Git cloning
- Automatic Docker build and start
- Secrets injection from AWS Parameter Store
- Application scaling

**Current Application:**
- Job Queue Microservices
- Frontend: React/Vue dashboard
- API: FastAPI backend
- Queue: Redis-based job processing

**How Application Deploys:**
1. User data script runs on EC2 boot
2. Clones git repo: `job-queue-microservices`
3. Retrieves secrets from Parameter Store
4. Creates `.env` file with credentials
5. Runs `docker compose up -d --build`
6. Services become available

**Application Endpoints:**
- Frontend: `https://infra.mosesekerin.name.ng/app`
- Dashboard: Interactive UI for job submission
- Status tracking: Real-time job status

---

### 9. Security Features

**What You Can Do:**
- SSH key-based access only (no passwords)
- Restrict SSH to specific CIDR
- Automatic security updates
- Firewall configured (UFW)
- Encrypted storage
- No credentials stored in code

**Security Controls:**
1. **SSH Hardening**
   - PermitRootLogin: no
   - PasswordAuthentication: no
   - PubkeyAuthentication: yes
   - Restricted CIDR: 102.93.7.11/32

2. **Network Security**
   - Security groups restrict traffic
   - Only needed ports open
   - Default deny, explicit allow

3. **Data Security**
   - EBS volumes encrypted
   - S3 state file encrypted
   - Secrets in Parameter Store
   - TLS for all network traffic

4. **Access Control**
   - IAM roles for services
   - OIDC for GitHub Actions
   - No long-lived credentials
   - Temporary token-based access

5. **Compliance**
   - Automated updates enabled
   - Audit logging (CloudTrail)
   - Encrypted storage
   - Access logging (Nginx)

---

### 10. Scalability Features

**Current Setup:**
- Single EC2 instance (can scale up)
- Single availability zone (can multi-AZ)
- Monolithic app (can separate services)
- Single database (can distributed)

**Scaling Capabilities Supported:**
1. **Vertical Scaling**
   ```bash
   # Change instance type in Terraform
   instance_type = "t3.small"  # Was t3.micro
   terraform apply
   # Existing data preserved, larger instance
   ```

2. **Horizontal Scaling** (future)
   - Auto-scaling group
   - Load balancer
   - Multiple instances

3. **Database Scaling** (future)
   - Managed RDS
   - Read replicas
   - Backup automation

4. **Container Scaling**
   ```bash
   docker compose up -d --scale worker=5
   # Scale worker service to 5 replicas
   ```

---

### 11. Disaster Recovery

**Current Capabilities:**
- Rebuild infrastructure from Terraform (< 5 minutes)
- State file backup in S3
- Configuration version controlled
- Deployment history in GitHub

**Disaster Recovery Procedure:**
```bash
# 1. Infrastructure destroyed/corrupted
# 2. Rebuild from Terraform
cd ~/hng-infrastructure-st0/environments/prod
terraform apply -var-file=example.tfvars

# Result: Complete infrastructure recreated
# Services started automatically
# Application deployed
```

**RTO (Recovery Time Objective):** ~5 minutes
**RPO (Recovery Point Objective):** 0 (infrastructure rebuild only)

---

### 12. Testing Capabilities

**What You Can Do:**
- Test infrastructure changes before deployment (terraform plan)
- Test workflows in CI/CD
- Test application endpoints
- Test monitoring and alerting

**Testing Workflows:**
```bash
# 1. Validate Terraform syntax
terraform validate

# 2. Format check
terraform fmt -check

# 3. Plan (dry-run)
terraform plan -var-file=example.tfvars

# 4. Manual testing
curl https://infra.mosesekerin.name.ng/health

# 5. End-to-end workflow validation
# (See PHASE_6_END_TO_END_TEST_PLAN.md)
```

---

## Feature Limitations

### Current Limitations

**Infrastructure:**
- Single AZ (no HA)
- Single instance (no redundancy)
- Single security group (no segmentation)
- No load balancer
- No database (stateless application)

**Monitoring:**
- 15-day retention (limited history)
- No external alerting (Slack, email)
- No custom metrics yet

**Logging:**
- 24-hour retention
- Label-based indexing (not full-text search)
- No log shipping to external service

**Application:**
- No auto-scaling
- No multi-region
- No CDN
- No caching layers

**Security:**
- SSH restricted to single CIDR
- No VPN or bastion host
- No intrusion detection
- No WAF

### Future Enhancements

**Phase 7: Reliability Engineering**
- Auto-scaling
- Multi-AZ deployment
- Load balancing
- Managed database
- SLO/SLI setup
- Alert routing (Slack, PagerDuty)

**Phase 8: Advanced Features**
- Multi-region deployment
- CDN integration
- Advanced security (WAF, DDoS)
- Cost optimization
- Disaster recovery runbooks

---

## Usage Statistics

### Infrastructure
- **Uptime:** 24/7 (as long as AWS availability)
- **Instance Type:** t3.micro (1 vCPU, 1GB RAM)
- **Storage:** 20GB EBS
- **Public IP:** Static (Elastic IP)

### Monitoring
- **Metrics Retention:** 15 days
- **Scrape Interval:** 15 seconds
- **Alert Evaluation:** 15 seconds

### Logging
- **Log Retention:** 24 hours
- **Log Sources:** 3+ (Nginx, system, application)
- **Query Performance:** <1 second

### Deployment
- **Time to Deploy:** ~3-5 minutes
- **Deployment History:** Full git history
- **Rollback Time:** ~3-5 minutes (re-apply previous commit)

---

## Access & Credentials

### Public Access
- **Domain:** infra.mosesekerin.name.ng
- **Protocol:** HTTPS
- **Certificate:** Let's Encrypt (auto-renewed)
- **Status:** Live

### Internal Access (via SSH)
```bash
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228
```

### Monitoring Access
- **Prometheus:** http://100.25.222.228:9090 (open)
- **Grafana:** http://100.25.222.228:3000 (admin/admin)
- **Loki:** http://100.25.222.228:3100 (API access)

### AWS Access
- **Account:** 617163942982
- **Region:** us-east-1
- **IAM Role:** github-actions-terraform (OIDC)

---

## Summary

This infrastructure provides:
- ✅ Production-ready deployment platform
- ✅ Complete observability (metrics + logs)
- ✅ Automated CI/CD
- ✅ Security hardening
- ✅ Disaster recovery capability
- ✅ Scalability path
- ✅ Open foundation for enhancement

It's suitable for learning, demonstration, and non-critical production applications.
