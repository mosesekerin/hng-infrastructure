# Repository Assets: Screenshots & Diagrams

## Visual Assets Strategy

This document references specific screenshots and diagrams that would enhance the documentation package. These assets make the project more accessible and impressive in presentations.

---

## Screenshots to Capture

### Terminal Screenshots

#### 1. Git Log (Proof of Incremental Development)
**File:** `screenshots/terminal/git_log.png`

```bash
git log --oneline --graph --all | head -30
```

**Shows:**
- Complete development history
- Phase-based commits
- Branch organization
- Feature development pattern

**Why:** Proves systematic development, not random commits

---

#### 2. Terraform Apply Output (Infrastructure Created)
**File:** `screenshots/terminal/terraform_apply_output.png`

```bash
cd ~/hng-infrastructure-st0/environments/prod
terraform apply -var-file=example.tfvars
```

**Shows:**
- Resources being created
- Apply progress
- Final outputs (IP, domain, etc.)

**Why:** Proof that infrastructure actually created

---

#### 3. Terraform State (Infrastructure Verification)
**File:** `screenshots/terminal/terraform_state_show.png`

```bash
terraform state list
# Output showing all resources
```

**Shows:**
- Complete infrastructure state
- Resource count
- Resource names

**Why:** Shows what's actually managed

---

#### 4. Docker Containers Running
**File:** `screenshots/terminal/docker_ps.png`

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Shows:**
- Frontend container running
- Backend API running
- Redis running
- Worker running

**Why:** Application stack is operational

---

#### 5. System Monitoring
**File:** `screenshots/terminal/system_stats.png`

```bash
# System info
uname -a
free -h
df -h
```

**Shows:**
- Ubuntu 22.04 LTS
- 1GB memory, minimal usage
- 20GB disk, healthy usage

---

#### 6. Service Status
**File:** `screenshots/terminal/service_status.png`

```bash
systemctl status nginx
systemctl status prometheus
systemctl status grafana-server
```

**Shows:**
- All services running
- Uptime
- Process IDs

---

#### 7. SSL Certificate
**File:** `screenshots/terminal/ssl_certificate.png`

```bash
sudo openssl x509 -in /etc/letsencrypt/live/infra.mosesekerin.name.ng/cert.pem -text -noout | grep -E "Subject:|Not Before|Not After"
```

**Shows:**
- Certificate issued
- Expiry date
- Certificate validity

---

### Web Screenshots

#### 8. HTTPS Root Page
**File:** `screenshots/web/root_page.png`

**URL:** `https://infra.mosesekerin.name.ng/`
**Shows:**
- HTTPS lock 🔒
- Username displayed
- Domain correct

**Captures:** Green lock, h1 with username

---

#### 9. Health Check Endpoint
**File:** `screenshots/web/health_check.png`

**URL:** `https://infra.mosesekerin.name.ng/health`
**Shows:**
- Simple "OK" response
- Plain text, no fancy markup
- Standard health check format

---

#### 10. API Endpoint (JSON Response)
**File:** `screenshots/web/api_response.png`

**URL:** `https://infra.mosesekerin.name.ng/api`
**Shows:**
- JSON formatted response
- Message, track, username
- Proper JSON structure

**Captures:**
```json
{
  "message": "HNGI14 Stage 1",
  "track": "DevOps",
  "username": "Timileyin-Your-Cloud/DevOps-Guy"
}
```

---

#### 11. Frontend Application
**File:** `screenshots/web/frontend_app.png`

**URL:** `https://infra.mosesekerin.name.ng/app`
**Shows:**
- Job Processor Dashboard
- Submit button
- UI working
- Responsive design

---

### Monitoring Dashboards

#### 12. Prometheus Dashboard
**File:** `screenshots/monitoring/prometheus_home.png`

**URL:** `http://100.25.222.228:9090`
**Shows:**
- Prometheus web UI
- Target status (green ✓)
- Graph interface
- Query builder

**Captures:**
- Targets: 2/2 up
- Alerts section
- Metrics query box

---

#### 13. Prometheus Targets
**File:** `screenshots/monitoring/prometheus_targets.png`

**URL:** `http://100.25.222.228:9090/targets`
**Shows:**
- Node Exporter: UP
- Prometheus self-monitoring: UP
- Scrape times
- Last scrape duration

---

#### 14. Prometheus Alerts
**File:** `screenshots/monitoring/prometheus_alerts.png`

**URL:** `http://100.25.222.228:9090/alerts`
**Shows:**
- Alert rules configured
- CPU usage alert
- Memory alert
- Disk alert

---

#### 15. Grafana Home
**File:** `screenshots/monitoring/grafana_home.png`

**URL:** `http://100.25.222.228:3000`
**Shows:**
- Grafana web UI
- Auto-provisioned dashboards
- Prometheus data source configured

---

#### 16. Grafana System Dashboard
**File:** `screenshots/monitoring/grafana_system_dashboard.png`

**URL:** `http://100.25.222.228:3000/d/system`
**Shows:**
- CPU usage graph
- Memory usage graph
- Disk usage graph
- Network traffic

**Captures:**
- Multiple panels
- Real-time data
- Professional appearance

---

#### 17. Grafana Alerts
**File:** `screenshots/monitoring/grafana_alerts.png`

**URL:** `http://100.25.222.228:3000/alerting/list`
**Shows:**
- Configured alert rules
- Thresholds
- Notification channels

---

### GitHub/CI-CD Screenshots

#### 18. GitHub Repository
**File:** `screenshots/github/repo_home.png`

**URL:** `https://github.com/mosesekerin/hng-infrastructure`
**Shows:**
- Repository name
- Description
- Files/folders
- README
- Stars (if public)

---

#### 19. GitHub Actions Workflows
**File:** `screenshots/github/actions_list.png`

**URL:** `https://github.com/mosesekerin/hng-infrastructure/actions`
**Shows:**
- plan.yml
- apply.yml
- destroy.yml
- Workflow run history
- Success rates

---

#### 20. Successful Plan Workflow
**File:** `screenshots/github/workflow_plan_success.png`

**URL:** `https://github.com/mosesekerin/hng-infrastructure/actions/runs/[ID]`
**Shows:**
- All steps green ✓
- Execution times
- Job summary
- Plan output

---

#### 21. Plan Workflow Logs
**File:** `screenshots/github/workflow_plan_logs.png`

**Shows:**
- terraform plan command
- Plan output (20+ lines)
- Resources: create, modify, destroy counts

---

#### 22. PR with Plan Comment
**File:** `screenshots/github/pr_plan_comment.png`

**URL:** `https://github.com/mosesekerin/hng-infrastructure/pull/[N]`
**Shows:**
- Pull request title
- PR description
- GitHub Actions bot comment
- Terraform plan output in comment
- Review interface

---

#### 23. Successful Apply Workflow
**File:** `screenshots/github/workflow_apply_success.png`

**Shows:**
- apply.yml execution
- All steps green ✓
- Deployment summary
- Extracted outputs (IP, domain)

---

#### 24. Git Commit History
**File:** `screenshots/github/git_log.png`

**Shows:**
- Phase-based commits
- Meaningful commit messages
- Incremental development
- Feature branches

---

### AWS Console Screenshots

#### 25. EC2 Instances
**File:** `screenshots/aws/ec2_instances.png`

**Shows:**
- Running instance
- Instance type: t3.micro
- Public IP: 100.25.222.228
- Status: Running
- Tags

---

#### 26. Security Groups
**File:** `screenshots/aws/security_groups.png`

**Shows:**
- Security group: prod-web-sg
- Inbound rules (80, 443, 22, etc.)
- Outbound rules (all)
- Rules list

---

#### 27. Route53 Records
**File:** `screenshots/aws/route53_records.png`

**Shows:**
- Hosted zone
- A records
- Domain: infra.mosesekerin.name.ng
- Points to: 100.25.222.228

---

#### 28. S3 State Bucket
**File:** `screenshots/aws/s3_bucket.png`

**Shows:**
- Bucket name: hng-terraform-state-*
- Versioning: Enabled
- Encryption: Enabled
- Files: terraform.tfstate

---

#### 29. IAM Role
**File:** `screenshots/aws/iam_role.png`

**Shows:**
- Role name: github-actions-terraform
- Trust policy: OIDC provider
- Attached policies
- Policy details

---

#### 30. Parameter Store
**File:** `screenshots/aws/parameter_store.png`

**Shows:**
- Parameter: /microapp/prod/redis_password
- Type: SecureString
- Encryption: KMS encrypted

---

---

## Diagrams to Create

### Architecture Diagrams

#### 31. System Architecture Diagram
**File:** `diagrams/architecture_system_diagram.png`

**Content:**
```
┌─ Internet ─────────────────────────────┐
│                                        │
│ GitHub (IaC, CI/CD) ←─ Developer      │
│         ↓ (OIDC)                      │
│    AWS Account (us-east-1)            │
│    ┌─────────────────────────────┐   │
│    │ VPC (10.0.0.0/16)          │   │
│    │ ┌─────────────────────────┐ │   │
│    │ │ Public Subnet           │ │   │
│    │ │ ┌───────────────────┐   │ │   │
│    │ │ │ EC2 (t3.micro)   │   │ │   │
│    │ │ │ - Nginx (443)    │   │ │   │
│    │ │ │ - Prometheus     │   │ │   │
│    │ │ │ - Grafana        │   │ │   │
│    │ │ │ - Docker Apps    │   │ │   │
│    │ │ └───────────────────┘   │ │   │
│    │ │ EIP: 100.25.222.228     │ │   │
│    │ └─────────────────────────┘ │   │
│    └─────────────────────────────┘   │
│                                      │
│ Route53 → infra.mosesekerin.name.ng  │
│ S3 → terraform.tfstate               │
│ Parameter Store → redis_password     │
│ IAM → github-actions-terraform       │
└─────────────────────────────────────────┘
```

---

#### 32. Data Flow Diagram
**File:** `diagrams/data_flow.png`

**Content:**
```
User Browser
  ↓ HTTPS GET /
  ↓
DNS (Route53)
  ↓
Nginx Reverse Proxy (443)
  ↓
Frontend Container (3001)
  ↓ (User interactions)
  ↓
Backend API (8000, internal)
  ↓
Redis Cache (6379, internal)
  ↓ (Response)
  ↓
Frontend (HTML/JS)
  ↓
Browser Renders
```

---

#### 33. CI/CD Pipeline Diagram
**File:** `diagrams/cicd_pipeline.png`

**Content:**
```
Developer
  ↓ git push
  ↓
GitHub PR
  ↓ (plan.yml trigger)
  ↓
GitHub Actions
  ├─ terraform init
  ├─ terraform plan
  └─ Comment PR with plan
      ↓ (Developer reviews)
      ↓ (Developer approves PR)
      ↓
  Merge to main
      ↓ (apply.yml trigger)
      ↓
  GitHub Actions
      ├─ terraform init
      ├─ terraform plan
      ├─ ⏸️ Approval Gate
      ├─ terraform apply
      └─ Extract outputs
          ↓
      AWS Resources
          ↓
      Infrastructure Updated
```

---

#### 34. Container Network Diagram
**File:** `diagrams/container_network.png`

**Content:**
```
Host: 100.25.222.228
  │
  ├─ Nginx (port 443/80)
  │   ├─ /          → frontend:3001
  │   ├─ /api       → Return JSON
  │   └─ /health    → Return OK
  │
  └─ Docker Network (172.17.0.0/16)
      ├─ Frontend Container
      │   └─ listens on 3001
      ├─ Backend Container
      │   └─ listens on 8000 (internal)
      ├─ Redis Container
      │   └─ listens on 6379 (internal)
      └─ Worker Container
          └─ background service
```

---

#### 35. Monitoring Data Flow
**File:** `diagrams/monitoring_data_flow.png`

**Content:**
```
System Metrics
  ↓
Node Exporter (9100)
  ↓
Prometheus (9090) - Scrapes every 15s
  ├─ Time-series DB
  └─ Stores metrics
      ↓
  Grafana (3000) - Queries on demand
      └─ Dashboards → Browser
```

---

#### 36. Logging Data Flow
**File:** `diagrams/logging_data_flow.png`

**Content:**
```
Multiple Log Sources
  ├─ Nginx access.log
  ├─ Nginx error.log
  ├─ Application logs
  └─ System logs
      ↓
Promtail (shipper)
  └─ Tails files, adds labels
      ↓
HTTP POST to Loki (3100)
  ├─ Log aggregation
  └─ Label indexing
      ↓
Query via Loki API / Grafana
  └─ Full log history
```

---

### Phase Progression Diagrams

#### 37. Project Phases
**File:** `diagrams/phases_progression.png`

**Content:**
```
Phase 1: Infrastructure Foundations ✅
  VPC, EC2, EIP, Route53, State
         ↓
Phase 3: HTTPS & Nginx ✅
  Let's Encrypt, TLS, Security Headers
         ↓
Phase 4: Monitoring ✅
  Prometheus, Grafana, Node Exporter
         ↓
Phase 5: Logging ✅
  Loki, Promtail, Log Aggregation
         ↓
Phase 6: CI/CD & Application ✅
  GitHub Actions, OIDC, Docker Stack
         ↓
Phase 7: Reliability Engineering 🔄 Planned
  SLOs, Alerting, Runbooks
         ↓
Phase 8: Advanced Features 🔄 Planned
  Auto-scaling, Multi-region, etc.
```

---

## How to Capture Screenshots

### Terminal Screenshots
```bash
# Use built-in screenshot tool or:
import -window root screenshot.png  # ImageMagick
gnome-screenshot -f screenshot.png   # GNOME

# Or record and pause:
# Use Ctrl+Shift+S (GNOME) or Print key
```

### Web Screenshots
```bash
# Use browser tools:
# Chrome DevTools → F12 → Ctrl+Shift+P → "Capture" screenshot
# Or use tool like scrot, import, or screenshot extension

# For full page:
# Firefox: Ctrl+Shift+S (Select region or full page)
# Chrome: Ctrl+Shift+P → "Capture full page screenshot"
```

### AWS Console Screenshots
- Login to AWS Console
- Navigate to resource
- Use browser screenshot (see above)
- Crop to highlight relevant parts

---

## Screenshot Organization

```
documentation/
├── README.md
├── 01_EXECUTIVE_SUMMARY.md
├── ... (other .md files)
└── screenshots/
    ├── terminal/
    │   ├── git_log.png
    │   ├── terraform_apply.png
    │   ├── docker_ps.png
    │   └── ssl_certificate.png
    ├── web/
    │   ├── root_page.png
    │   ├── health_check.png
    │   ├── api_response.png
    │   └── frontend_app.png
    ├── monitoring/
    │   ├── prometheus_home.png
    │   ├── prometheus_targets.png
    │   ├── grafana_home.png
    │   ├── grafana_dashboard.png
    │   └── grafana_alerts.png
    ├── github/
    │   ├── repo_home.png
    │   ├── actions_list.png
    │   ├── workflow_plan.png
    │   ├── pr_plan_comment.png
    │   └── workflow_apply.png
    ├── aws/
    │   ├── ec2_instances.png
    │   ├── security_groups.png
    │   ├── route53_records.png
    │   ├── s3_bucket.png
    │   └── iam_role.png
    └── diagrams/
        ├── architecture_system.png
        ├── data_flow.png
        ├── cicd_pipeline.png
        ├── container_network.png
        ├── monitoring_flow.png
        └── phases_progression.png
```

---

## Where to Reference Screenshots

### In Documentation

**Example Usage:**

```markdown
## Live Deployment

The infrastructure is live and operational:

![HTTPS Root Page](screenshots/web/root_page.png)
*Live HTTPS endpoint showing username*

All services are running:

![Docker Containers](screenshots/terminal/docker_ps.png)
*Frontend, Backend, Redis, and Worker services running*

Monitoring is operational:

![Grafana Dashboard](screenshots/monitoring/grafana_dashboard.png)
*System metrics dashboard showing health*

The complete CI/CD pipeline:

![CI/CD Pipeline](diagrams/cicd_pipeline.png)
*Automated deployment workflow*
```

---

## Value of Visual Assets

Screenshots and diagrams:
- ✅ Make documentation more accessible
- ✅ Prove infrastructure actually exists
- ✅ Show progression clearly
- ✅ Help in interviews (visual explanations)
- ✅ Add to portfolio (visual proof)
- ✅ Make GitHub README more impressive

**Recommendation:** Add top 10-15 most impressive screenshots to main README, rest in documentation.
