# Interview Preparation: HNG Infrastructure

## Quick Reference Talking Points

### 30-Second Elevator Pitch
"I built a production-grade infrastructure on AWS using Terraform where a single terraform apply command creates the entire system. It includes HTTPS with auto-renewing certificates, a complete monitoring stack with Prometheus and Grafana, centralized logging with Loki, and a fully automated CI/CD pipeline with GitHub Actions that uses OIDC for secure credentials. Zero manual deployment steps. Zero secrets stored in code."

### 2-Minute Technical Overview
"The project is a complete infrastructure-as-code deployment across 6 phases. Phase 1 established the VPC, EC2, and DNS on AWS. Phase 3 added HTTPS with Let's Encrypt auto-renewal. Phase 4 deployed Prometheus and Grafana for monitoring, Phase 5 added Loki for log aggregation, and Phase 6 built the CI/CD pipeline using GitHub Actions with OIDC for temporary credentials.

The architecture is fundamentally: user requests hit Nginx HTTPS on port 443, which reverse-proxies to a containerized frontend application, which talks to an internal backend API and Redis cache. Everything is version-controlled in Git, infrastructure changes are validated in pull requests, and deployments require manual approval.

I also debugged and solved 5 major issues including terraform state management, GitHub Actions output parsing, IAM permission cascades, and Nginx reverse proxy configuration.

The project demonstrates infrastructure as code, CI/CD automation, monitoring, logging, security hardening, and systematic problem-solving."

### 5-Minute Deep Dive
*See "Common Interview Questions" section below for full answers*

---

## Common Interview Questions & Answers

### Q1: "Walk me through your architecture"

**Answer Structure:**
1. Start with user → end with data
2. Each component's purpose
3. How components communicate
4. Why each choice

**Your Answer:**
"When a user visits infra.mosesekerin.name.ng, their request goes to Route53 DNS, which returns our Elastic IP (100.25.222.228). They connect via HTTPS to Nginx on port 443.

Nginx acts as our reverse proxy and terminates TLS. We get a valid certificate from Let's Encrypt, automatically renewed every 90 days via Certbot. The certificate lives in /etc/letsencrypt.

Nginx forwards the request to our frontend application running in a Docker container on port 3001. The frontend can make API calls to the backend (port 8000, internal only) and query Redis for caching.

The backend, Redis, and worker services all run in Docker Compose on the same host, isolated from the public internet by not exposing their ports.

All infrastructure is defined in Terraform. The VPC (10.0.0.0/16) contains our single public subnet. A single security group controls all traffic. The EC2 instance has an IAM role for accessing AWS services.

For observability, Prometheus scrapes metrics from Node Exporter every 15 seconds and stores them in a time-series database. Grafana queries Prometheus to display dashboards.

For logging, Promtail tails log files and ships them to Loki for aggregation and querying.

All code and configuration is in Git. Terraform changes trigger GitHub Actions workflows that plan changes in PRs and apply them on merge (with approval gate).

This design achieves reproducibility—I can destroy everything and rebuild in 5 minutes. It achieves auditability—every change is in Git. It achieves security—no stored credentials (OIDC temporary tokens), HTTPS everywhere, encryption at rest and in transit."

---

### Q2: "What was the most challenging problem you solved?"

**Answer Structure:**
1. Problem description
2. Why it was difficult
3. Your debugging approach
4. The solution
5. Lesson learned

**Your Answer (Pick One Major Issue):**

"The most challenging was debugging variable substitution in the user_data.sh script. The error manifested as Nginx displaying the process ID (2917558) instead of the actual username.

This was difficult because it involved three layers:
- Terraform's templatefile() function (uses ${variable} syntax)
- Bash variable expansion (also uses ${variable})
- Shell escape sequences ($$)

The root cause: I used $$${ thinking the first $$ would escape to $ and then ${} would be literal. But bash interpreted $$ as the process ID before the escape could work.

My debugging approach: I SSHed to the instance, checked the actual script, saw the bad substitution, tested manually with correct values, then traced back to the Terraform code.

The solution: Use Terraform's templatefile() syntax directly (${hng_username}), letting Terraform inject the variable value, rather than trying to escape it for Bash.

Lesson: Understanding each technology's syntax separately prevents these conflicts. Don't try to be clever with escaping—use each tool's intended mechanism."

**Alternative Issues to Discuss:**
- Terraform plan hanging (missing variables)
- GitHub Actions debug metadata pollution (output parsing)
- IAM permission cascades
- SSL certificate NXDOMAIN
- Docker service discovery

---

### Q3: "Why did you choose Terraform over CloudFormation/Pulumi?"

**Answer:**
"Three reasons:

1. **Portability:** Terraform is cloud-agnostic. If I ever need to move to Azure or GCP, the syntax remains 90% the same. CloudFormation locks you into AWS.

2. **HCL Language:** Terraform's HCL is more readable than CloudFormation's JSON/YAML. It's designed specifically for infrastructure, not a general-purpose format.

3. **Learning Value:** Terraform is industry-standard for DevOps. CloudFormation is AWS-specific. I wanted to build skills that transfer.

The trade-off is more tool-specific knowledge for Terraform, but the portability is worth it for a learning project."

---

### Q4: "How did you handle secrets and credentials?"

**Answer:**
"Zero secrets are stored in code. Here's the strategy:

1. **OIDC for GitHub Actions:** Instead of storing AWS IAM access keys in GitHub, I configured an OIDC provider. GitHub Actions receives temporary STS tokens that expire in 1 hour. No credentials stored anywhere.

2. **Parameter Store for Application Secrets:** The Redis password is stored in AWS Parameter Store with KMS encryption. The EC2 instance has an IAM role allowing it to read this parameter at startup. Application environment files are created at runtime.

3. **SSH Keys:** SSH private key is stored locally on my machine with file permissions 600 (read-only by owner). Public key is in EC2 authorized_keys.

4. **Terraform Variables:** Sensitive variables come from -var-file=example.tfvars (in git) which contains non-sensitive example values. Local terraform.tfvars (gitignored) contains actual values for local development.

The principle: Credentials are temporary (OIDC), encrypted (KMS), restricted (IAM roles), and never stored in code/git.

This follows AWS best practices and eliminates the risk of credential leakage if the repo is compromised."

---

### Q5: "Walk me through your CI/CD pipeline"

**Answer:**
"Three workflows:

**plan.yml (Pull Request):**
- Triggers on PR to main
- Runs terraform fmt check, validate, and plan
- Converts binary plan output to text
- Comments on PR with the plan output
- Developer can see exactly what will change

**apply.yml (Deployment):**
- Triggers on merge to main
- Runs terraform init and plan again
- Pauses for approval (production environment)
- Runs terraform apply when approved
- Extracts outputs (IP, domain) and posts summary

**destroy.yml (Cleanup):**
- Manual trigger only
- Requires typed confirmation
- Requires approval
- Backs up state first
- Destroys all infrastructure

**Key Features:**
1. **OIDC:** GitHub Actions assumes a role; receives temporary credentials
2. **Approval Gates:** No automatic production deployment
3. **Audit Trail:** Every deployment logged in GitHub
4. **State Management:** Remote state in S3 with versioning
5. **Dry Run First:** Plan shows changes before apply

The workflow ensures no surprise deployments and full visibility of changes."

---

### Q6: "How do you handle monitoring and debugging?"

**Answer:**
"Three layers:

**Metrics (Prometheus):**
- Node Exporter exports system metrics (CPU, memory, disk, network)
- Prometheus scrapes every 15 seconds
- Stores data as time-series
- Grafana visualizes dashboards
- Can query with PromQL for ad-hoc analysis

**Logs (Loki):**
- Promtail ships logs from Nginx and system
- Loki aggregates with label-based indexing
- Queryable by labels (job, filename, level)
- Integrated into Grafana

**Application Health:**
- Health check endpoint (/health) for status
- Structured Nginx logs for request analysis
- Docker container health checks

**When Something Breaks:**
1. Check monitoring dashboard (Grafana)
2. SSH to instance
3. Check service status (systemctl, docker ps)
4. Check logs (journalctl, docker logs, Loki)
5. Reproduce locally if possible
6. Fix and push
7. Observe recovery via monitoring

This approach prevents flying blind. Monitoring catches issues before users notice."

---

### Q7: "What would you do differently for production?"

**Answer:**
"Several improvements:

**Reliability:**
1. Multi-AZ deployment (failover capability)
2. Load balancer (distribution, health checks)
3. Auto-scaling (handle traffic spikes)
4. Database backup (RDS with automated backups)
5. Regular disaster recovery testing

**Security:**
1. Reduce IAM permissions (currently broad)
2. Network segmentation (separate security groups per tier)
3. WAF (Web Application Firewall)
4. Secrets rotation (automated)
5. GuardDuty (threat detection)

**Observability:**
1. Alert routing (Slack, PagerDuty)
2. Custom metrics (business logic)
3. Distributed tracing
4. SLOs/SLIs formalization
5. Runbooks (documented procedures)

**Operations:**
1. Terraform Cloud (managed state)
2. Cost optimization (spot instances, reserved capacity)
3. Backup automation (regular testing)
4. Incident response plan (documented)
5. On-call rotation

These are all designed for production, not learning. The current setup is right-sized for the use case."

---

### Q8: "Tell me about a debugging session"

**Answer (GitHub Actions Output Parsing):**

"GitHub Actions was failing at the 'Get Outputs' step with an error about invalid GITHUB_OUTPUT format.

The step was trying:
```bash
terraform output -raw public_ip
# Expected: 100.25.222.228
# Got: 100.25.222.228::debug::Terraform exited with code 0.
```

The ::debug:: broke GitHub's expected format. I initially thought terraform was outputting garbage, but then realized GitHub Actions debug metadata was being mixed in.

I debugged by:
1. Reading the actual error carefully (it showed the ::debug:: portion)
2. Researching GitHub Actions command format
3. Testing locally (terraform output worked fine)
4. Filtering the output: grep -v '::debug::' | grep -v '::'

The fix: Clean output before writing to GITHUB_OUTPUT
```bash
instance_ip=$(terraform output -raw public_ip 2>&1 | grep -v '::debug::' | head -1)
echo "instance_ip=${instance_ip}" >> $GITHUB_OUTPUT
```

This was valuable because it taught me: CI/CD systems have their own quirks. Always understand the tool's output format, not just the command's output."

---

## Interview Questions You Might Ask

### Q: "What would you do if the certificate renewal failed?"

**Answer:**
"Let's encrypt renews 30 days before expiry, so there's time to fix it.

1. Check manual renewal: `certbot renew --force-renewal`
2. Check logs: `sudo journalctl -u certbot`
3. Verify DNS: `nslookup infra.mosesekerin.name.ng`
4. If it still fails, manually request: `certbot certonly --nginx -d infra.mosesekerin.name.ng`
5. Reload Nginx: `systemctl reload nginx`
6. Verify: `curl -I https://infra.mosesekerin.name.ng/` (should show cert in response)

Prevention: Monitoring dashboard alerts if cert expiry is approaching. Renewal hooks ensure Nginx reloads after renewal."

---

### Q: "How would you scale this to handle 10x traffic?"

**Answer:**
"Several layers:

**Application Layer:**
- Upgrade instance (t3.micro → t3.large)
- Multiple application instances behind load balancer
- Container auto-scaling

**Database Layer:**
- RDS (if we add real database)
- Read replicas for distribution
- Connection pooling

**Content Layer:**
- CloudFront CDN for static files
- Reduce server load

**Monitoring Layer:**
- Auto-scaling based on CPU/memory
- Load testing to find limits
- Performance profiling

The current architecture supports scaling. Would take maybe 2-3 days to implement multi-instance setup."

---

### Q: "What's your biggest learning from this project?"

**Answer:**
"Understanding principles over tools. I learned that Infrastructure as Code is a principle (automate, version, reproduce) that applies regardless of tool. Likewise, security is about principles (least privilege, encryption, audit), not just specific tools.

Someone who understands these principles can pick up Pulumi if Terraform becomes outdated. Someone who just memorized Terraform syntax can't."

---

## Questions to Ask Back

### Demonstrate Engagement:
1. "What observability patterns does your organization use?"
2. "How do you handle Terraform state management at scale?"
3. "What's your incident response process?"
4. "How do you balance automation with operational safety?"

---

## Red Flags to Avoid

❌ **Don't:**
- Overstate what you know
- Pretend debugging was easy (be honest about struggles)
- Memorize answers (sound natural)
- Bad-mouth tools (compare objectively)
- Avoid admitting limitations
- Claim expertise you don't have

✅ **Do:**
- Explain reasoning clearly
- Show systematic approach
- Admit when you don't know
- Offer to find out
- Show curiosity about the role
- Be authentic

---

## Interview Format Guide

### Phone/Video Screen (30-45 min)
- Expect: High-level architecture, why decisions
- Example flow:
  - "Tell me about your project" (2 min)
  - "What was the hardest part?" (3 min)
  - "Walk me through the architecture" (5 min)
  - "Describe a debugging session" (5 min)
  - "Questions for us?" (2 min)

### Technical Interview (1-2 hours)
- Expect: Deep questions, design decisions
- Possible: Live coding (Terraform), system design
- Prepare: Have architecture diagram ready (maybe whiteboard)

### System Design Interview
- Expect: "Design X for production"
- You have an advantage: you've done this
- Use your project as reference
- Talk through trade-offs

---

## Closing Statement

**If asked "Why should we hire you?" based on this project:**

"This project demonstrates I can build production-quality infrastructure. It shows systems thinking (integrating multiple technologies), attention to detail (security, monitoring, logging), problem-solving (debugging 5 complex issues), and communication (comprehensive documentation).

More importantly, it shows I understand principles: automation, reproducibility, security, observability. I don't just know tools—I know why we use them.

I'm ready to apply these patterns to your infrastructure, help your team move faster, and bring this level of discipline to everything I build."

---

## Last-Minute Tips

- ✅ Bring project repo URL (have it ready to share screen)
- ✅ Have architecture diagram ready to explain
- ✅ Be prepared to deep-dive on 1-2 topics
- ✅ Have a story about debugging (makes you memorable)
- ✅ Ask thoughtful questions about their stack
- ✅ Reference specific technologies confidently
- ✅ Admit when you'd need to learn something
