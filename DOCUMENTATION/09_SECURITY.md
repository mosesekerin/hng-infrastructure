# Security Analysis: HNG Infrastructure

## Executive Summary

This infrastructure implements **industry-standard security practices** appropriate for a learning project and non-critical production system.

**Security Posture:** Strong for the use case
**Critical Vulnerabilities:** None identified
**Recommended Priority:** Medium (no immediate action required, but improvements possible)

---

## Security Layers

### 1. Network Security

#### VPC Isolation
- ✅ Resources in private VPC (10.0.0.0/16)
- ✅ Public subnet restricted
- ✅ No cross-VPC connectivity
- ✅ Internet Gateway controlled access

#### Security Groups
- ✅ Implicit deny (default-drop)
- ✅ Explicit allow rules
- ✅ SSH restricted to single CIDR (102.93.7.11/32)
- ✅ HTTP/HTTPS publicly accessible
- ✅ Monitoring ports public (future improvement: restrict to specific IPs)

#### Network Segmentation
- ⚠️ Single security group (no internal segmentation)
- ⚠️ All services can communicate internally
- ✅ Docker network provides container isolation

#### DNS Security
- ✅ Route53 with encryption
- ⚠️ No DNSSEC enabled
- ✅ DNS records version controlled

### 2. Access Control

#### SSH Authentication
- ✅ Key-based only (no passwords)
- ✅ SSH keys not stored in git
- ✅ PermitRootLogin = no
- ✅ PasswordAuthentication = no
- ✅ SSH restricted to 102.93.7.11/32

#### AWS IAM
- ✅ GitHub Actions uses OIDC (no stored credentials)
- ✅ Temporary 1-hour session tokens
- ✅ Principle of least privilege (mostly)
- ⚠️ IAM wildcard (*) on some actions (EC2, IAM, VPC)

#### Secrets Management
- ✅ Redis password in Parameter Store
- ✅ Encrypted with KMS
- ✅ Not in code or logs
- ⚠️ Limited to single secret (simple approach)

#### Docker Access
- ✅ No default credentials
- ✅ Custom built images (not base images)
- ⚠️ Docker daemon accessible to ubuntu user only

### 3. Data Security

#### Encryption at Rest
- ✅ EBS volumes encrypted (AES-256)
- ✅ S3 state file encrypted (AES-256)
- ✅ Parameter Store encrypted (KMS)
- ✅ Nginx certificates stored on instance (encrypted partition)

#### Encryption in Transit
- ✅ HTTPS for all client connections
- ✅ TLS 1.2+ required
- ✅ Strong ciphers configured
- ✅ HSTS enabled (31536000 seconds)
- ✅ Docker internal network (encrypted by default)

#### Data Retention
- ✅ Log retention: 24 hours (Loki)
- ✅ Metrics retention: 15 days (Prometheus)
- ✅ State file backup: Automated
- ⚠️ No application data backup (stateless app)

### 4. Application Security

#### Nginx Security Headers
```
✅ Strict-Transport-Security: max-age=31536000
✅ X-Frame-Options: DENY
✅ X-Content-Type-Options: nosniff
✅ X-XSS-Protection: 1; mode=block
✅ Referrer-Policy: no-referrer-when-downgrade
✅ Permissions-Policy: geolocation(), microphone(), camera()
```

#### SSL/TLS Configuration
- ✅ TLS 1.2 and 1.3 only
- ✅ Strong cipher suites (ECDHE-*)
- ✅ Certificate auto-renewal
- ✅ Valid certificate from Let's Encrypt

#### Application Input Validation
- ⚠️ No rate limiting on API (Nginx rate limiting: 30 req/s general, 10 req/s API)
- ⚠️ Frontend application validation unknown (external dependency)
- ✅ Backend in container (isolated from host)

### 5. Infrastructure Security

#### EC2 Hardening
- ✅ Ubuntu LTS (security updates)
- ✅ Automatic security patches (future: enable unattended-upgrades)
- ✅ UFW firewall enabled
- ✅ Minimum required services
- ✅ No SSH X11 forwarding

#### IAM Role for EC2
- ✅ Scoped permissions only
- ✅ Cannot modify security groups
- ✅ Cannot terminate instance
- ✅ Can read secrets from Parameter Store

#### Volume Security
- ✅ EBS encrypted
- ✅ No public snapshot capability
- ✅ No cross-account access

### 6. Monitoring & Logging Security

#### Audit Trail
- ✅ CloudTrail (implicit in AWS)
- ✅ GitHub Actions logs all deployments
- ✅ Git history shows all changes
- ✅ SSH attempts logged
- ✅ Nginx access logs structured

#### Log Access
- ⚠️ Monitoring ports publicly accessible
- ⚠️ No authentication on Prometheus (default)
- ⚠️ Grafana default password (admin/admin)
- ✅ Logs don't contain secrets

#### Alerting
- ✅ Alert rules configured
- ⚠️ No external alert routing (to Slack, PagerDuty)
- ✅ Can query logs manually

---

## Threat Model

### Threats Mitigated

| Threat | Impact | Mitigation |
|--------|--------|-----------|
| Brute force SSH | High | Key-based auth only |
| Credential leakage | Critical | OIDC + no stored keys |
| Network access | Medium | Security groups restrict |
| Data breach | Medium | Encryption at rest/transit |
| Unauthorized changes | Medium | Git history + approval gates |
| Service compromise | Medium | Container isolation |
| SSL MITM | High | HTTPS + valid certs |
| Insider threat | Medium | OIDC prevents key theft |

### Residual Threats

| Threat | Likelihood | Impact | Mitigation Path |
|--------|-----------|--------|-----------------|
| DDoS attack | Low | High | Add CloudFront CDN or WAF |
| Container escape | Low | High | Implement Pod Security Policy |
| Stolen SSH key | Medium | Critical | SSH agent + key rotation policy |
| Monitoring port abuse | Medium | Medium | Restrict to VPN/bastion |
| Accidental data delete | Low | Medium | Automated backups |
| Certificate expiry | Low | Critical | Monitoring (already in place) |
| Terraform state corruption | Low | High | Backup (already in place) |

---

## Security Best Practices Implemented

### ✅ Implemented

1. **Principle of Least Privilege**
   - SSH only from specific CIDR
   - IAM roles scoped
   - Security groups explicit allow

2. **Defense in Depth**
   - Network layer (security groups)
   - Application layer (HTTPS, headers)
   - Infrastructure layer (IAM roles)
   - Data layer (encryption)

3. **Encryption Everywhere**
   - At rest (EBS, S3, Parameter Store)
   - In transit (HTTPS, TLS)
   - Certificates from trusted CA

4. **Zero Trust for Credentials**
   - OIDC temporary tokens
   - No long-lived keys
   - Automatic rotation

5. **Audit Trail**
   - CloudTrail (AWS)
   - GitHub Actions
   - Git history
   - Nginx logs

6. **Security Automation**
   - Automatic security updates
   - Certificate auto-renewal
   - Terraform validates infrastructure

7. **Secret Management**
   - Parameter Store for secrets
   - Not in code or git
   - Encrypted storage

### ⚠️ Improvements for Production

1. **Add Bastion Host**
   - SSH through jump box
   - Centralized access logging
   - Easier to rotate credentials

2. **Implement Network Segmentation**
   - Separate security groups per tier
   - App → Database (only)
   - Monitoring → App (only)

3. **Enable WAF (Web Application Firewall)**
   - Protect against application attacks
   - SQL injection, XSS, etc.
   - AWS WAF integration

4. **Restrict Monitoring Access**
   - Prometheus behind authentication
   - Grafana with RBAC
   - VPN requirement

5. **Enable Guardduty/Security Hub**
   - Threat detection
   - Compliance monitoring
   - Automated responses

6. **Implement Secrets Rotation**
   - Automatic credential rotation
   - Before expiry
   - No manual intervention

7. **Add VPC Flow Logs**
   - Monitor all network traffic
   - Detect anomalies
   - Compliance evidence

8. **Enable CloudTrail logging**
   - Log all AWS API calls
   - Multi-account access
   - S3 with encryption

9. **Implement Config Rules**
   - Verify security group configs
   - Encryption enabled
   - Compliance checks

10. **Add Intrusion Detection**
    - Host-based (HIDS)
    - Network-based (NIDS)
    - Automated response

---

## Security Vulnerabilities Assessment

### Critical (None Identified)

### High
**1. Grafana Default Credentials**
- **Issue:** admin/admin easily guessable
- **Fix:** Change password immediately
- **Impact:** Anyone with network access can access Grafana
- **Effort:** 5 minutes

**2. Monitoring Ports Publicly Accessible**
- **Issue:** Prometheus (9090), Loki (3100) publicly available
- **Fix:** Restrict to VPN or bastion host
- **Impact:** Information disclosure (metrics expose infrastructure details)
- **Effort:** 30 minutes (security group + bastion setup)

### Medium
**1. Broad IAM Permissions**
- **Issue:** github-actions-terraform has iam:* permission
- **Fix:** Limit to specific IAM actions
- **Impact:** If OIDC token compromised, can modify any IAM policy
- **Effort:** 1 hour (audit and restrict permissions)

**2. Single Security Group**
- **Issue:** No network segmentation
- **Fix:** Create separate groups (public, app, data)
- **Impact:** Container escape could access all services
- **Effort:** 2 hours (redesign security groups)

**3. No Secrets Rotation Policy**
- **Issue:** SSH keys, certificates not rotated periodically
- **Fix:** Implement automated rotation
- **Impact:** Long-lived credentials increase compromise risk
- **Effort:** 4 hours (create rotation automation)

### Low
**1. No SSH 2FA**
- **Issue:** Only SSH keys protect access
- **Fix:** Add SSH certificate or U2F
- **Impact:** Compromised key = full access
- **Effort:** 2-3 hours (setup SSH certificate authority)

**2. Unattended Upgrades Not Enabled**
- **Issue:** Security patches require manual intervention
- **Fix:** Enable unattended-upgrades
- **Impact:** Potential for outdated security patches
- **Effort:** 15 minutes

**3. No Log Alerting**
- **Issue:** Errors not automatically notified
- **Fix:** Setup log-based alerts
- **Impact:** Slower incident response
- **Effort:** 1 hour (Grafana alert rules)

---

## Compliance Considerations

### HIPAA
- ❌ Not compliant (PHI handling not implemented)
- Would require: Encryption everywhere, audit logging, BAA

### PCI DSS
- ❌ Not compliant (credit card data not handled)
- Would require: Network segmentation, vulnerability scanning, formal security policy

### SOC 2
- ⚠️ Partially implementable
- Have: Encryption, access controls, audit logs
- Need: Formal policies, incident response plan, security assessments

### GDPR
- ⚠️ Partially implementable
- Have: Encryption, data retention limits, audit trail
- Need: Data subject rights, data protection officer, processing agreements

### General Best Practices
- ✅ Encryption at rest
- ✅ Encryption in transit
- ✅ Access controls
- ✅ Audit trail
- ⚠️ Backup and recovery (infrastructure only)
- ⚠️ Incident response plan (not documented)
- ⚠️ Security awareness (not applicable for solo dev)

---

## Security Recommendations

### Immediate (Do First)
1. Change Grafana default password
   ```bash
   ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228
   # Change password in Grafana UI
   ```

2. Restrict Monitoring Ports
   ```hcl
   # In Terraform security group
   ingress {
     from_port   = 9090
     to_port     = 9090
     protocol    = "tcp"
     cidr_blocks = ["102.93.7.11/32"]  # Only your IP
   }
   ```

### Short Term (Phase 7)
1. Reduce IAM permissions (iam:* → specific actions)
2. Implement SSH key rotation policy
3. Enable unattended-upgrades
4. Add VPC Flow Logs
5. Setup log-based alerting

### Long Term (Phase 8)
1. Implement bastion host
2. Add WAF (Web Application Firewall)
3. Implement network segmentation
4. Enable GuardDuty
5. Implement secrets rotation
6. Add intrusion detection

---

## Security Testing Checklist

- [ ] Verify HTTPS certificate validity
- [ ] Test SSH key-based auth only
- [ ] Verify security group rules
- [ ] Check IAM permissions
- [ ] Test Parameter Store access
- [ ] Verify no secrets in logs
- [ ] Check encryption status
- [ ] Verify audit trail
- [ ] Test disaster recovery
- [ ] Review firewall rules

---

## Incident Response Plan

### Suspected Breach

1. **Contain**
   - Revoke SSH keys immediately
   - Rotate secrets in Parameter Store
   - Review CloudTrail logs for unauthorized access

2. **Investigate**
   - Check all logs (CloudTrail, Nginx, application)
   - Identify scope of breach
   - Determine access method

3. **Remediate**
   - Change compromised credentials
   - Patch any exploited vulnerabilities
   - Update security groups
   - Rebuild if necessary

4. **Recovery**
   - Restore from backup if needed
   - Verify systems integrity
   - Restore from clean backup

5. **Post-Incident**
   - Document incident
   - Update security controls
   - Review and improve

---

## Security Checklist for Production

Before moving to production:
- [ ] Change all default credentials
- [ ] Enable WAF
- [ ] Setup intrusion detection
- [ ] Enable GuardDuty
- [ ] Configure VPC Flow Logs
- [ ] Setup centralized logging
- [ ] Implement backup strategy
- [ ] Document incident response plan
- [ ] Create runbooks
- [ ] Conduct security audit
- [ ] Implement secrets rotation
- [ ] Setup 24/7 monitoring

---

## Security Conclusion

**Current Status:** Suitable for learning and non-critical systems

**For Production:** Implement High and Medium priority recommendations

**Ongoing:** Security is not a one-time effort; continuously improve based on threats and best practices.
