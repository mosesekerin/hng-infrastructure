# Operational Guide: HNG Infrastructure

## Quick Reference

### Common Operations

#### Check Infrastructure Status
```bash
cd ~/hng-infrastructure-st0/environments/prod

# What resources exist
terraform show

# Current outputs (IP, domain)
terraform output

# Check specific resource
terraform state show aws_instance.web
```

#### SSH to Instance
```bash
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228

# Or use the output
INSTANCE_IP=$(terraform output -raw public_ip)
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@$INSTANCE_IP
```

#### Monitor Deployment
```bash
# Via GitHub Actions
# Visit: https://github.com/mosesekerin/hng-infrastructure/actions

# Watch plan.yml
# → Shows terraform plan in PR comment

# Watch apply.yml
# → Shows deployment progress
# → Wait for approval gate
# → Approve deployment
# → Watch terraform apply
```

---

## Common Troubleshooting

### Problem: Infrastructure Unreachable

**Symptoms:** Cannot reach infra.mosesekerin.name.ng

**Debugging Steps:**

1. **Check DNS Resolution**
```bash
nslookup infra.mosesekerin.name.ng
# Should show: 100.25.222.228
```

2. **Check AWS Instance Status**
```bash
aws ec2 describe-instances --region us-east-1 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
# Should show: running state
```

3. **Check Security Group**
```bash
aws ec2 describe-security-groups \
  --group-ids sg-0e6f10d9a1efb6794 \
  --query 'SecurityGroups[0].IpPermissions' \
  --output table
# Should allow: 443/tcp, 80/tcp
```

4. **Test Connectivity**
```bash
# From your computer
ping 100.25.222.228
curl -I https://infra.mosesekerin.name.ng

# SSH to instance
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228
```

5. **Check Service Status**
```bash
# On the instance
sudo systemctl status nginx
sudo systemctl status prometheus
sudo systemctl status grafana-server

# Restart if needed
sudo systemctl restart nginx
```

### Problem: Nginx Returns 502 Bad Gateway

**Possible Causes:**

1. **Frontend Container Down**
```bash
# SSH to instance
docker ps
# Look for: job-queue-microservices-frontend-1 status

# Check logs
docker logs job-queue-microservices-frontend-1

# Restart if needed
docker compose restart frontend
```

2. **Nginx Configuration Error**
```bash
# Test configuration
sudo nginx -t
# Should show: "syntax is ok"

# If error, check config
sudo cat /etc/nginx/nginx.conf | grep -A 5 "upstream"

# Reload if fixed
sudo systemctl reload nginx
```

3. **Network Issues**
```bash
# Check Docker network
docker network ls
docker network inspect job-queue-microservices_default

# Restart Docker service
sudo systemctl restart docker
docker compose up -d
```

### Problem: High CPU or Memory Usage

**Monitoring:**

1. **View Current Usage**
```bash
# SSH to instance
top
# Shows: CPU, memory, processes

# Or via Prometheus
# Visit: http://100.25.222.228:9090
# Query: node_cpu_seconds_total, node_memory_MemAvailable_bytes
```

2. **Identify Heavy Process**
```bash
ps aux | sort -nrk 3,3 | head -n 10
# Sort by CPU usage

ps aux | sort -nrk 4,4 | head -n 10
# Sort by memory usage
```

3. **Reduce Load**
```bash
# Restart problematic container
docker compose restart <service_name>

# Or scale down if replicated
docker compose up -d --scale worker=1

# Or upgrade instance (via Terraform)
# Change: instance_type = "t3.small"
# Run: terraform apply
```

### Problem: SSL Certificate Issues

**Check Certificate Status:**
```bash
# SSH to instance
sudo openssl x509 -in /etc/letsencrypt/live/infra.mosesekerin.name.ng/cert.pem -text -noout | grep -E "Subject:|Not Before|Not After"

# Should show: Valid dates (future expiry)
```

**Manual Renewal:**
```bash
# If auto-renewal fails
sudo certbot renew --force-renewal

# Check renewal status
sudo certbot certificates

# Check Nginx reload hook
sudo ls -la /etc/letsencrypt/renewal-hooks/post/
```

### Problem: Storage Full

**Check Disk Usage:**
```bash
# SSH to instance
df -h
# Shows: disk usage by mount point

du -sh /var/log/*
# Shows: log file sizes

du -sh /opt/*
# Shows: application sizes
```

**Clean Up:**
```bash
# Rotate old logs
sudo logrotate -f /etc/logrotate.conf

# Clear old Docker images
docker image prune -a

# Clear old containers
docker container prune

# Reduce Prometheus retention
# Edit: /opt/prometheus/prometheus.yml
# Change: storage.tsdb.retention.time=7d
```

---

## Maintenance Tasks

### Daily
- Monitor dashboard: http://100.25.222.228:3000
- Check alerts (if configured)
- Review error logs

### Weekly
```bash
# Check certificate expiry
certbot certificates

# Verify all services running
docker ps
systemctl status nginx prometheus grafana-server

# Review disk usage
df -h
```

### Monthly
```bash
# Security updates
sudo apt update && sudo apt upgrade -y

# Backup state file (already done in S3)
aws s3 ls s3://hng-terraform-state-617163942982/prod/

# Review logs
sudo tail -100 /var/log/nginx/access.log
sudo tail -100 /var/log/user-data.log
```

### Quarterly
```bash
# Review infrastructure
terraform plan -var-file=example.tfvars
# Should show: No changes (if configs unchanged)

# Test disaster recovery
# Optionally: terraform destroy (if safe)
# Then: terraform apply (verify rebuild)

# Review and update documentation
```

---

## Deployment Process

### Standard Deployment

1. **Make Changes**
```bash
git checkout -b feature/description
vim environments/prod/main.tf  # or other files
```

2. **Test Locally**
```bash
terraform plan -var-file=example.tfvars
# Review: what will change?
```

3. **Commit and Push**
```bash
git add -A
git commit -m "feat: descriptive message"
git push origin feature/description
```

4. **Open PR on GitHub**
- GitHub automatically runs `plan.yml`
- Plan shows in PR comment

5. **Review Plan**
- Ensure changes are expected
- No accidental deletions
- Costs acceptable

6. **Approve and Merge**
- Merge to main in GitHub
- GitHub automatically runs `apply.yml`
- Click "Review Deployments"
- Select "production" environment
- Click "Approve and deploy"

7. **Monitor Deployment**
- Watch apply.yml execution
- Check deployment summary

8. **Verify Changes**
```bash
# Verify infrastructure
terraform output

# Verify services
curl https://infra.mosesekerin.name.ng/health

# Check logs
sudo tail -f /var/log/nginx/access.log
```

### Rollback Procedure

**If deployment causes issues:**

1. **Identify Problem**
```bash
# Check infrastructure
terraform plan -var-file=example.tfvars

# Check logs
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228
sudo tail -f /var/log/nginx/error.log
```

2. **Revert Commit**
```bash
# Find last working commit
git log --oneline

# Revert problematic commit
git revert <commit-hash>
git push origin main

# Or reset to previous commit
git reset --hard <commit-hash>
git push -f origin main
```

3. **Monitor Rollback**
- apply.yml runs automatically
- Infrastructure reverts to previous state

4. **Verify Recovery**
```bash
curl https://infra.mosesekerin.name.ng/health
# Should return: OK
```

---

## Scaling Operations

### Scale Up Instance

```bash
# Edit Terraform
vim environments/prod/main.tf

# Change:
instance_type = "t3.small"  # was t3.micro

# Or change volume size:
root_volume_size = 50  # was 20

# Plan changes
terraform plan -var-file=example.tfvars

# Deploy
terraform apply -var-file=example.tfvars
```

**Note:** t3.micro to t3.small requires instance stop/start (downtime ~1-2 minutes)

### Scale Out Application

```bash
# SSH to instance
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228

# Scale worker replicas
cd /home/ubuntu/micro-service-app/job-queue-microservices
docker compose up -d --scale worker=3

# Verify
docker ps | grep worker
```

### Add Monitoring Alert

1. **Via Prometheus Rules**
```bash
# SSH to instance
sudo vim /opt/prometheus/alert_rules.yml

# Add alert rule
- alert: CustomAlert
  expr: node_cpu_seconds_total > threshold
  for: 5m
  annotations:
    summary: "CPU high"

# Reload Prometheus
sudo systemctl reload prometheus
```

2. **Via Grafana**
- Visit: http://100.25.222.228:3000
- Create dashboard → Add panel → Set alert rule

---

## Backup & Recovery

### State File Backup

**Automatic (via GitHub Actions):**
```bash
# destroy.yml automatically backs up state
aws s3 cp /path/to/terraform.tfstate \
  s3://hng-terraform-state-617163942982/backups/terraform.tfstate.backup.$(date +%s)
```

**Manual Backup:**
```bash
# SSH to instance or run locally
aws s3 cp s3://hng-terraform-state-617163942982/prod/terraform.tfstate \
  ~/backup-terraform.tfstate

# Verify backup
aws s3 ls s3://hng-terraform-state-617163942982/
```

### State File Recovery

**If state is corrupted:**

1. **Retrieve Backup**
```bash
aws s3 cp s3://hng-terraform-state-617163942982/backups/terraform.tfstate.backup.<timestamp> \
  ~/terraform.tfstate.backup
```

2. **Restore**
```bash
# Initialize new backend
terraform init -reconfigure

# Get backup state
aws s3 cp s3://hng-terraform-state-617163942982/backups/terraform.tfstate.backup.<timestamp> \
  environments/prod/terraform.tfstate

# Push state back
terraform state push environments/prod/terraform.tfstate
```

3. **Verify**
```bash
terraform plan -var-file=example.tfvars
# Should match actual AWS resources
```

---

## Monitoring Dashboard

### Key Metrics to Watch

**On Grafana (http://100.25.222.228:3000):**

1. **System Health**
   - CPU usage (should be <20% idle)
   - Memory available (should be >500MB)
   - Disk free (should be >5GB)

2. **Service Status**
   - Nginx uptime
   - Container health
   - Database connections (if applicable)

3. **Performance**
   - Request latency (should be <100ms)
   - Throughput (requests/second)
   - Error rate (should be <1%)

4. **Infrastructure**
   - Instance state (running)
   - Network traffic
   - Cost tracking

### Prometheus Useful Queries

```promql
# System uptime (seconds)
node_time_seconds

# CPU usage percentage
rate(node_cpu_seconds_total[5m]) * 100

# Memory available
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024  # in GB

# Disk usage percentage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Load average
node_load1, node_load5, node_load15
```

---

## Emergency Procedures

### Total Infrastructure Failure

**Recovery Steps:**

1. **Determine Scope**
- Is DNS working? (try nslookup)
- Is AWS instance running? (check console)
- Are services running? (try SSH)

2. **Full Rebuild**
```bash
# If instance is gone
cd ~/hng-infrastructure-st0/environments/prod
terraform apply -var-file=example.tfvars

# This rebuilds:
# - VPC, subnets
# - Security groups
# - EC2 instance
# - Nginx, monitoring, application
# Expected time: 5-10 minutes
```

3. **Verify Services**
```bash
# Check all endpoints
curl https://infra.mosesekerin.name.ng/
curl https://infra.mosesekerin.name.ng/health
curl https://infra.mosesekerin.name.ng/api

# Check services
docker ps
sudo systemctl status nginx
sudo systemctl status prometheus
```

### Certificate Expiry

**Prevention:**
- Certbot automatically renews 30 days before expiry
- Check: `certbot certificates`

**If Expiry Occurs:**
```bash
# Renew immediately
sudo certbot renew --force-renewal

# Restart Nginx
sudo systemctl restart nginx

# Verify
curl -I https://infra.mosesekerin.name.ng/
# Should show: HTTP/2 200
```

### Container Crash

**Recovery:**

```bash
# Check container status
docker ps -a | grep <container_name>

# View crash logs
docker logs <container_name>

# Restart container
docker compose restart <container_name>

# If persistent, rebuild
docker compose up -d --build <container_name>

# Check health
docker ps
```

---

## Performance Tuning

### Nginx Optimization
```bash
# Increase worker connections
sudo vim /etc/nginx/nginx.conf
# Change: worker_connections 4096 -> 8192

# Increase buffer sizes
# Add to http block:
client_body_buffer_size 128k;
client_max_body_size 10m;

# Reload
sudo systemctl reload nginx
```

### Docker Optimization
```bash
# Limit container resources
docker update --cpus=0.5 --memory=512m <container_name>

# Or in docker-compose.yml:
services:
  frontend:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Prometheus Optimization
```bash
# Reduce retention period
# Edit: /opt/prometheus/prometheus.yml
storage:
  tsdb:
    retention:
      time: 7d  # from 15d

# Or increase storage
root_volume_size = 50  # in Terraform
```

---

## Support & Escalation

### Where to Check

1. **GitHub Issues**
   - Repository: hng-infrastructure
   - Check existing issues
   - Report new issues

2. **Application Logs**
   - SSH to instance
   - `/var/log/nginx/` - web server
   - `/var/log/user-data.log` - initialization
   - `docker logs <container>` - application

3. **Monitoring Dashboards**
   - Grafana: http://100.25.222.228:3000
   - Prometheus: http://100.25.222.228:9090
   - Loki: http://100.25.222.228:3100

4. **AWS Console**
   - EC2 instances
   - Security groups
   - Route53 records
   - S3 state bucket

---

## Checklists

### Pre-Deployment
- ☐ Local terraform plan shows expected changes
- ☐ No accidental deletions
- ☐ Estimated costs acceptable
- ☐ Change reviewed and approved
- ☐ Backup ready (if major changes)

### Post-Deployment
- ☐ Infrastructure shows in terraform output
- ☐ Services return HTTP 200
- ☐ Monitoring dashboard shows health
- ☐ No error logs
- ☐ Git history updated
- ☐ Documentation updated if needed

### Incident Response
- ☐ Identify scope (infrastructure, service, application)
- ☐ Check logs for root cause
- ☐ Attempt fix
- ☐ Monitor recovery
- ☐ Document incident
- ☐ Implement prevention
