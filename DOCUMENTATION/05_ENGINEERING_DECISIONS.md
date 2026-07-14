# Engineering Decisions: HNG Infrastructure

## Major Architectural Decisions

### Decision 1: Modular Terraform Structure

**Decision:** Organize Terraform code into separate modules (networking, compute, security, dns, monitoring)

**Why Made:**
- Code reusability
- Separation of concerns
- Easier testing and maintenance
- Clear dependency graph
- Scalability for future projects

**Alternatives Considered:**
1. **Monolithic main.tf** - Single file for all resources
   - Pros: Simple for small projects
   - Cons: Becomes unmanageable as project grows, hard to test modules independently
   
2. **Environment-based structure** - Separate folders for dev/staging/prod
   - Pros: Clear environment separation
   - Cons: Code duplication across environments

**Trade-offs:**
- ❌ More complex directory structure
- ✅ Better code organization
- ✅ Reusable modules for future projects
- ✅ Easier to maintain

**Final Reasoning:** Modular approach teaches best practices and scales better for learning DevOps properly.

---

### Decision 2: No DynamoDB State Locks

**Decision:** Use S3-only state backend without DynamoDB locking

**Why Made:**
- Solo developer (no concurrent applies needed)
- Simplifies infrastructure
- Reduces operational complexity
- No additional service to maintain
- Removes failure point

**Alternatives Considered:**
1. **DynamoDB state locks** (initial implementation)
   - Pros: Prevents concurrent modification
   - Cons: Lock contention issues, adds complexity for solo dev
   
2. **Terraform Cloud** - Remote state + locking managed
   - Pros: Fully managed, built-in approval gates
   - Cons: External dependency, less learning value, costs for private repos

**Trade-offs:**
- ❌ Cannot safely run concurrent terraform applies (not needed)
- ✅ Simpler backend configuration
- ✅ Fewer things to debug
- ✅ No external state lock service

**Final Reasoning:** Removed when state lock issues arose; solo developer scenario doesn't need complex locking.

**Lesson Learned:** State locking solves real problems but only when they exist; evaluate necessity per use case.

---

### Decision 3: OIDC Authentication for GitHub Actions

**Decision:** Use OpenID Connect for AWS authentication instead of storing IAM credentials

**Why Made:**
- Industry security best practice
- Zero credential leakage risk
- Automatic token rotation
- Full audit trail
- No credential management burden

**Alternatives Considered:**
1. **AWS Access Keys** - Long-lived credentials in GitHub Secrets
   - Pros: Simple setup
   - Cons: Credentials stored, rotation risk, single point of failure
   
2. **AWS STS AssumeRole** - Chained role assumption
   - Pros: Better than access keys
   - Cons: More complex, similar to OIDC

**Trade-offs:**
- ⚠️ Requires AWS IAM setup (one-time)
- ✅ Zero credentials stored
- ✅ Automatic 1-hour token expiration
- ✅ Best security practice

**Final Reasoning:** Learning proper security practices is part of the project goal; OIDC is the modern standard.

---

### Decision 4: Template File for User Data Variables

**Decision:** Use Terraform templatefile() to inject variables into user_data.sh

**Why Made:**
- Declarative infrastructure (variables in Terraform)
- Single source of truth
- Avoid hardcoding values in script
- Proper IaC practice
- Easy to change configurations

**Alternatives Considered:**
1. **Hardcoded values in user_data.sh**
   - Pros: Simple, no templating needed
   - Cons: Not IaC, configuration mixed with code
   
2. **Environment variables in EC2**
   - Pros: Flexible
   - Cons: Not version controlled, harder to debug

3. **AWS Systems Manager Documents**
   - Pros: Centralized management
   - Cons: Overkill for single instance, adds complexity

**Trade-offs:**
- ⚠️ Requires understanding templatefile() syntax
- ✅ Configuration in Terraform
- ✅ Version controlled
- ✅ Easy to change per environment

**Final Reasoning:** Best IaC practice; complexity worth the learning value.

---

### Decision 5: Reverse Proxy for Frontend

**Decision:** Run frontend in Docker, proxy through Nginx on port 3001

**Why Made:**
- Clean separation of concerns
- HTTPS termination at Nginx
- Frontend serves via Nginx
- Security (backend internal only)

**Alternatives Considered:**
1. **Direct access to Docker port** - User connects to :3001 directly
   - Pros: No reverse proxy complexity
   - Cons: No HTTPS, no rate limiting, no unified access point
   
2. **API Gateway/ALB** - AWS managed reverse proxy
   - Pros: Managed service
   - Cons: Additional AWS resource, cost, complexity

**Trade-offs:**
- ⚠️ Nginx configuration complexity
- ✅ Single HTTPS entry point
- ✅ Rate limiting and security headers
- ✅ Standard production pattern

**Final Reasoning:** Real-world production pattern; teaches proper web server usage.

---

### Decision 6: Keep Backend API Internal Only

**Decision:** Backend API (port 8000) not exposed to internet, only frontend access

**Why Made:**
- Security (no direct API access)
- Architecture (frontend serves as gateway)
- Microservices best practice
- Reduced attack surface

**Alternatives Considered:**
1. **Public API endpoint** - Backend accessible from /api
   - Pros: Direct API access for testing
   - Cons: Security risk, bypasses frontend, not needed
   
2. **Separate API subdomain** - api.infra.mosesekerin.name.ng
   - Pros: Separation of concerns
   - Cons: Over-engineered for single instance

**Trade-offs:**
- ⚠️ Can only test API from within frontend
- ✅ Smaller attack surface
- ✅ Better security posture
- ✅ Microservices pattern

**Final Reasoning:** Security and architecture alignment outweigh convenience of public API.

---

### Decision 7: Prometheus + Grafana for Monitoring

**Decision:** Self-hosted Prometheus and Grafana instead of managed service

**Why Made:**
- Learning value (understand monitoring stack)
- Cost-free (open-source)
- Full control
- Portable (can move to any infrastructure)
- Industry-standard stack

**Alternatives Considered:**
1. **AWS CloudWatch** - Native AWS monitoring
   - Pros: AWS integrated
   - Cons: Limited free tier, less learning
   
2. **DataDog** - SaaS monitoring
   - Pros: Managed, comprehensive
   - Cons: Cost, external dependency, less learning
   
3. **Prometheus only** - Skip Grafana, use Prometheus UI
   - Pros: Simpler
   - Cons: Limited visualization

**Trade-offs:**
- ⚠️ Must manage services
- ⚠️ Requires configuration
- ✅ Cost-free
- ✅ Standard monitoring stack
- ✅ Full learning value

**Final Reasoning:** Project goal is learning DevOps; self-hosted stack teaches proper architecture.

---

### Decision 8: Loki for Log Aggregation

**Decision:** Use Loki + Promtail for centralized logging

**Why Made:**
- Label-based indexing (efficient)
- Prometheus-compatible
- Lightweight compared to ELK
- Open-source
- Integration with Grafana

**Alternatives Considered:**
1. **ELK Stack** (Elasticsearch, Logstash, Kibana)
   - Pros: Most popular
   - Cons: Resource-heavy, complex, expensive
   
2. **No centralized logging** - Only file-based logs
   - Pros: Simpler
   - Cons: Hard to search across services
   
3. **Splunk** - Commercial log management
   - Pros: Powerful
   - Cons: Expensive, overkill for single instance

**Trade-offs:**
- ⚠️ Label-based (less flexible than full-text search)
- ✅ Lightweight
- ✅ Grafana integration
- ✅ Cost-free

**Final Reasoning:** Loki is modern alternative to ELK; teaches newer approaches.

---

### Decision 9: Dockerfile Build in User Data

**Decision:** Run `docker-compose up -d --build` during EC2 initialization

**Why Made:**
- Automatic application deployment
- No manual Docker commands needed
- Image built on instance
- Self-contained initialization

**Alternatives Considered:**
1. **Pre-built Docker images** - Push images to Docker Hub, just pull
   - Pros: Faster deployment
   - Cons: Manual image build step, external dependency
   
2. **Docker Compose already running** - No build needed
   - Pros: Simple
   - Cons: Requires repo access, more complex git operations

**Trade-offs:**
- ⚠️ First-time boot slower (Docker build)
- ⚠️ Larger user data script
- ✅ Fully automated
- ✅ No external image dependency

**Final Reasoning:** Automation worth the initial boot time cost.

---

### Decision 10: GitHub Actions Approval Gates

**Decision:** Require manual approval in GitHub production environment before applying

**Why Made:**
- Safety gate for production
- Human review before changes
- Prevents automated mistakes
- Audit trail of approvals
- Industry standard practice

**Alternatives Considered:**
1. **No approvals** - Auto-apply on main merge
   - Pros: Faster deployments
   - Cons: Risk of bad changes going to production
   
2. **External approval service** - Separate approval system
   - Pros: More sophisticated
   - Cons: Unnecessary complexity

**Trade-offs:**
- ⚠️ Slightly slower deployment (waiting for approval)
- ✅ Safety gate
- ✅ Audit trail
- ✅ Production best practice

**Final Reasoning:** Safety outweighs marginal deployment time increase.

---

### Decision 11: Two-File Variable Strategy

**Decision:** Maintain both terraform.tfvars (local, gitignored) and example.tfvars (committed)

**Why Made:**
- Local values for development
- CI/CD compatible values committed
- No sensitive data in git
- Clear template for team members

**How It Works:**
- Developer uses terraform.tfvars locally
- CI/CD uses -var-file=example.tfvars
- Both files kept in sync manually

**Alternatives Considered:**
1. **Single terraform.tfvars** - Committed to git
   - Pros: Single file
   - Cons: Credentials in git (bad practice)
   
2. **Only example.tfvars** - No local override
   - Pros: Single source of truth
   - Cons: Must edit committed file locally
   
3. **Environment-based loading** - Automatic .tfvars selection
   - Pros: Automatic
   - Cons: Complex shell logic

**Trade-offs:**
- ⚠️ Manual file sync required
- ⚠️ Must maintain two files
- ✅ Flexibility for local development
- ✅ CI/CD can use example.tfvars
- ✅ No secrets in git

**Final Reasoning:** Manual sync acceptable for solo developer; teaches good practices.

---

### Decision 12: Structured Logging Format

**Decision:** Implement custom log format with structured fields

**Format:**
```
$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" request_time=$request_time upstreamtime=$upstream_response_time
```

**Why Made:**
- Machine-parseable (log aggregation)
- Performance metrics (request_time, upstream_time)
- Structured for Loki ingestion
- Easy to grep/search
- Industry standard

**Alternatives Considered:**
1. **Default Nginx format** - Built-in format
   - Pros: No customization needed
   - Cons: Not structured, harder for aggregation
   
2. **JSON format** - Structured JSON per line
   - Pros: Fully structured
   - Cons: More verbose, harder to read in terminal

**Trade-offs:**
- ⚠️ Custom format needs documentation
- ✅ Performance data included
- ✅ Parseable by log aggregators
- ✅ Readable in terminal

**Final Reasoning:** Balance between machine-parseable and human-readable.

---

### Decision 13: Skip AWS-Managed Services Where Possible

**Decision:** Use self-hosted services (Prometheus, Loki) instead of AWS services (CloudWatch)

**Why Made:**
- Learning (understand full stack)
- Portability (not AWS-locked-in)
- Cost-free (open-source)
- Control (can customize)

**Alternatives Considered:**
1. **CloudWatch** - AWS managed
   - Pros: Integrated, no management
   - Cons: Less learning, limited free tier
   
2. **Mix of both** - Use AWS where makes sense
   - Pros: Best of both worlds
   - Cons: Complexity, multiple tools

**Trade-offs:**
- ⚠️ Must manage services
- ⚠️ More complexity
- ✅ Deep learning
- ✅ Cost-free
- ✅ Portable skills

**Final Reasoning:** Project is learning-focused; managing services is the point.

---

### Decision 14: Enable Nginx Gzip Compression

**Decision:** Enable gzip compression for text responses

**Configuration:**
```nginx
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_types text/plain text/css application/json text/javascript;
```

**Why Made:**
- Reduces bandwidth
- Faster page loads
- Minimal CPU cost
- Industry standard

**Alternatives Considered:**
1. **No compression** - Serve full-size
   - Pros: Simpler
   - Cons: Larger bandwidth

2. **More aggressive compression** - Lower min_length
   - Pros: More files compressed
   - Cons: Marginal benefit, more CPU

**Trade-offs:**
- ⚠️ Slight CPU overhead (negligible on t3.micro)
- ✅ Bandwidth reduction
- ✅ Better user experience

**Final Reasoning:** Standard practice; cost-benefit is positive.

---

### Decision 15: Single Availability Zone

**Decision:** Deploy everything to single availability zone (us-east-1a)

**Why Made:**
- Simplicity for learning
- Cost-free (no NAT gateway between AZs)
- Sufficient for non-critical infrastructure

**For Production Multiple AZs Would Be:**
- VPC with multiple subnets (different AZs)
- Multiple EC2 instances
- Load balancer
- RDS with failover

**Current Limitations:**
- Single point of failure
- No automatic failover
- RTO/RPO requires full rebuild from Terraform

**Decision Rationale:** Learning project; single AZ acceptable for non-critical work. Multi-AZ adds significant complexity not justified at this stage.

---

## Implementation Decisions

### Decision 16: No Infrastructure Cost Optimization

**Decision:** Use t3.micro instance (sufficient for learning)

**Why Made:**
- Free tier eligible
- Sufficient for monitoring stack
- Learning-focused (not production scale)
- Cost-free operation

**Real Production Would Consider:**
- Spot instances (80% cheaper)
- Reserved instances (longer term)
- Right-sizing based on metrics

**Final Reasoning:** Cost optimization out of scope for learning project.

---

## Security Decisions

### Decision 17: SSH Key-Only Authentication

**Decision:** Disable password authentication, require SSH keys

**Configuration:**
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

**Why Made:**
- Industry standard
- Prevent brute force attacks
- No password management burden
- Audit-friendly (key-based access)

**Alternatives Considered:**
1. **Passwords** - Traditional authentication
   - Pros: Familiar
   - Cons: Brute force risk, management burden

**Trade-offs:**
- ⚠️ Must manage SSH keys
- ✅ Better security posture
- ✅ No password leaks
- ✅ Audit trail

**Final Reasoning:** Security best practice; worth the key management.

---

### Decision 18: Restrict SSH CIDR

**Decision:** SSH only from specific IP CIDR (102.93.7.11/32)

**Why Made:**
- Limit attack surface
- Only engineer's IP can connect
- Reduces SSH scan attempts
- Security hardening

**Alternatives Considered:**
1. **Allow all (0.0.0.0/0)** - Anyone can attempt SSH
   - Pros: Flexible
   - Cons: Huge attack surface
   
2. **Bastion host** - Jump through proxy
   - Pros: Extra security layer
   - Cons: Overkill for single instance

**Trade-offs:**
- ⚠️ Cannot SSH from other networks
- ✅ Dramatically reduced attack surface
- ✅ Simpler than bastion host

**Final Reasoning:** Balance between security and usability.

---

## Summary of Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State Management | S3 no locks | Solo dev, simplicity |
| Authentication | OIDC | Security best practice |
| Variables | Terraform + template | IaC best practice |
| Frontend | Docker + Nginx proxy | Production pattern |
| Backend | Internal only | Security |
| Monitoring | Self-hosted Prometheus | Learning value |
| Logging | Loki | Lightweight, modern |
| Secrets | Parameter Store | AWS native |
| Approval Gates | Yes | Production safety |
| SSH | Key-only, restricted CIDR | Security hardening |

All decisions balance between learning value, security, production-readiness, and simplicity.
