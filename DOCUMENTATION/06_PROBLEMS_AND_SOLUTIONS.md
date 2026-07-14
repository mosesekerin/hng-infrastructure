# Problems Encountered & Solutions: HNG Infrastructure

## Overview

This document captures all major problems encountered during the project, the systematic debugging process used to diagnose them, and the solutions implemented. This represents real-world problem-solving in DevOps engineering.

---

## Problem 1: Terraform Plan Hanging for 5+ Minutes

### Symptoms Observed
- GitHub Actions workflow `plan.yml` triggered on PR
- Workflow starts normally (checkout, AWS login, terraform init all pass)
- At "Terraform Plan" step, the workflow hangs indefinitely
- After ~5 minutes, GitHub Actions cancels the workflow with timeout
- No error messages, just hung waiting for something

### Initial Hypotheses
1. AWS API slowness
2. Terraform state lock contention
3. Large state file processing
4. Network connectivity issue
5. Terraform waiting for user input (most likely)

### Debugging Process

**Step 1: Check GitHub Actions Logs**
- Looked at workflow execution logs
- Saw: `terraform plan -no-color -lock=false -var-file=example.tfvars -out=tfplan`
- No error output, just hung

**Step 2: Test Terraform Plan Locally**
```bash
cd ~/hng-infrastructure-st0/environments/prod
terraform plan -var-file=example.tfvars
```
- Ran successfully locally (< 30 seconds)
- No hanging observed
- This meant the issue was GitHub Actions-specific, not Terraform

**Step 3: Investigate Variables**
- Realized: GitHub Actions runner has no interactive terminal
- Terraform must be waiting for a variable value
- Checked example.tfvars for missing variables
- Found: `deploy_public_key` was NOT in example.tfvars
- Local terraform.tfvars had the value, but example.tfvars didn't

**Step 4: Confirm Root Cause**
```bash
# Simulate what CI/CD does
terraform plan -var-file=example.tfvars
# If variable missing, terraform would prompt for input
# But GitHub Actions can't provide input → hangs forever
```

### Root Cause
**Terraform waiting for interactive input when variable undefined.** GitHub Actions runners have no terminal input capability, so terraform hangs forever waiting for keyboard input that will never come.

### Solution Implemented

**Add missing variables to example.tfvars:**
```hcl
deploy_public_key = "ssh-rsa AAAA... user@email.com"
```

**Verification:**
```bash
terraform plan -var-file=example.tfvars
# Now completes successfully
```

### Lesson Learned
- ✅ Always provide all variables needed by CI/CD in committed config files
- ✅ Terraform will hang (not timeout) waiting for input
- ✅ Test locally with exact CI/CD command: `terraform plan -var-file=example.tfvars`
- ⚠️ Interactive workflows don't work in CI/CD; must be non-interactive

---

## Problem 2: Terraform Output Parsing Failed

### Symptoms Observed
- GitHub Actions workflow progresses past `terraform plan`
- Fails at "Comment PR with Plan" step
- Error: `Error: ENOENT: no such file or directory, open 'environments/prod/plan.txt'`
- This is JavaScript error from GitHub Actions script action

### Root Cause Analysis

**The "Comment PR with Plan" step was trying to:**
```javascript
const plan = fs.readFileSync('environments/prod/plan.txt')
// But plan.txt doesn't exist!
```

**Why it doesn't exist:**
- `terraform plan -out=tfplan` creates binary file `tfplan`
- `plan.txt` is never created
- The step was looking for wrong filename

### Debugging Process

**Step 1: Understand terraform plan output**
```bash
terraform plan -out=tfplan
# Result: binary file 'tfplan' (not human-readable)
```

**Step 2: Convert binary to text**
```bash
terraform show tfplan
# Result: human-readable terraform plan
```

**Step 3: Add conversion step**
```bash
terraform show -no-color tfplan > plan.txt
# Now plan.txt exists and contains readable plan
```

### Solution Implemented

**Add new step before "Comment PR with Plan":**
```yaml
- name: Convert Plan to Text
  working-directory: environments/prod
  run: |
    terraform show -no-color tfplan > plan.txt
```

**Why this works:**
- `terraform show` converts binary tfplan to readable text
- `-no-color` removes color codes (cleaner output)
- Redirects to `plan.txt` file
- Next step can now read the file

### Lesson Learned
- ✅ Binary outputs need conversion for text processing
- ✅ `terraform show` is the tool to read binary plans
- ✅ Shell redirection (`>`) creates files for downstream steps
- ⚠️ Each step has its own working directory context

---

## Problem 3: GitHub Actions Output Format Error

### Symptoms Observed
- GitHub Actions workflow progresses past "Comment PR with Plan"
- Fails at "Get Outputs" step
- Error message: `Error: Unable to process file command 'output' successfully`
- Additional error: `Error: Invalid format '100.25.222.228::debug::Terraform exited with code 8.'`

### Investigation

**The step was trying to:**
```bash
terraform output -raw public_ip
# Expected output: 100.25.222.228
# Actual output: 100.25.222.228::debug::Terraform exited with code 8.
```

**Then writing to GitHub Output:**
```bash
echo "instance_ip=$(terraform output -raw public_ip)" >> $GITHUB_OUTPUT
# Writes: instance_ip=100.25.222.228::debug::Terraform exited with code 8.
# GitHub Actions can't parse this format (the ::debug:: breaks the format)
```

### Root Cause

**GitHub Actions debug output was being mixed with actual output.**

When terraform outputs to stdout, GitHub Actions runner also adds debug metadata:
```
100.25.222.228::debug::Terraform exited with code 0.
```

The `::debug::` is a GitHub Actions command format that broke the expected `key=value` format.

### Debugging Process

**Step 1: Look at raw output**
- Examined GitHub Actions logs carefully
- Saw the `::debug::` portion in the error message

**Step 2: Understand GitHub Actions output format**
- GitHub Actions expects: `key=value`
- Debug metadata like `::debug::` breaks this format
- GitHub Actions tries to interpret `::debug::` as a command

**Step 3: Filter the output**
```bash
# Use grep to remove debug lines
terraform output -raw public_ip 2>&1 | grep -v '::debug::'
# Result: Clean output without debug metadata
```

### Solution Implemented

**Updated "Get Outputs" step to filter debug output:**
```bash
instance_ip=$(terraform output -raw public_ip 2>&1 | grep -v '::debug::' | grep -v '::' | head -1)
domain=$(terraform output -raw domain_name 2>&1 | grep -v '::debug::' | grep -v '::' | head -1)

echo "instance_ip=${instance_ip}" >> $GITHUB_OUTPUT
echo "domain=${domain}" >> $GITHUB_OUTPUT
```

**What each part does:**
- `2>&1` - Capture both stdout and stderr
- `grep -v '::debug::'` - Remove debug lines
- `grep -v '::'` - Remove any GitHub Actions command format lines
- `head -1` - Take only first line (the value)

### Lesson Learned
- ✅ GitHub Actions adds metadata to stdout
- ✅ Must filter output before writing to GITHUB_OUTPUT
- ✅ `2>&1 | grep` pattern for cleaning output
- ✅ `head -1` to extract single value from multi-line output
- ⚠️ Debug metadata can break downstream processing

---

## Problem 4: IAM Permission Denied on terraform plan

### Symptoms Observed
- GitHub Actions workflow progresses past "Terraform Init"
- Fails at "Terraform Plan" step
- Error: `Error: reading IAM Role (prod-web-role): operation error IAM: GetRole, https response error StatusCode: 403, RequestId: ..., api error AccessDenied`
- Message: "User is not authorized to perform: iam:GetRole on resource: role prod-web-role"

### Analysis

The error shows:
```
terraform trying to read: aws_iam_role.web resource
AWS denying with: AccessDenied on iam:GetRole
```

**Why terraform needs to read the role:**
- Terraform manages IAM resources
- On `terraform plan`, it must read current state from AWS
- Reading the role requires `iam:GetRole` permission
- GitHub Actions role didn't have this permission

### Root Cause

**GitHub Actions IAM role lacked IAM read permissions.**

Initial policy had:
- EC2 permissions (*)
- VPC permissions (*)
- Route53 permissions (*)
- Missing: IAM permissions (to read roles)

### Debugging Process

**Step 1: Check IAM role policy**
```bash
aws iam get-role-policy --role-name github-actions-terraform --policy-name terraform-permissions
# Output showed: EC2, VPC, Route53 only
# Missing: IAM permissions
```

**Step 2: Check what permissions are needed**
- Error says: `iam:GetRole` needed
- But would also need: `iam:ListAttachedRolePolicies`, `iam:GetRolePolicy`, etc.
- Better to just grant: `iam:*` (all IAM permissions)

**Step 3: Update policy**
```bash
aws iam put-role-policy --role-name github-actions-terraform --policy-name terraform-permissions --policy-document file://policy.json
# Added "iam:*" to policy
```

### Solution Implemented

**Added IAM section to GitHub Actions IAM policy:**
```json
{
  "Sid": "IAMFullAccess",
  "Effect": "Allow",
  "Action": ["iam:*"],
  "Resource": "*"
}
```

### Escalation

**Initial thought:** Add only specific IAM permissions needed
- `iam:GetRole`
- `iam:GetRolePolicy`
- `iam:ListRolePolicies`
- `iam:GetInstanceProfile`

**Problem:** As terraform plan ran, it found MORE missing permissions
- Each missing permission caused a separate error
- This would require multiple iterations

**Decision:** Grant `iam:*` to complete the setup
- Better for learning (see full impact)
- Faster iteration
- Can be tightened later in production

### Lesson Learned
- ✅ Terraform needs READ permissions on resources it manages
- ✅ Must grant IAM permissions to read IAM resources
- ✅ Missing permissions show up during `terraform plan` read phase
- ✅ Iterative debugging: fix one permission, then find next missing one
- ⚠️ GitHub Actions needs broad permissions for Terraform IaC
- ⚠️ Security trade-off: Broad permissions vs. iterative debugging

---

## Problem 5: Variable Substitution Showing Process ID

### Symptoms Observed
- Terraform plan and apply succeed
- EC2 instance launches, Nginx starts
- Browser shows: `<h1>2917558{HNG_USERNAME:-Your-Username}</h1>`
- Expected: `<h1>Timileyin-Your-Cloud/DevOps-Guy</h1>`
- Number `2917558` is the process ID (PID)

### Root Cause Analysis

**In user_data.sh script, this line was:**
```bash
HNG_USERNAME="$$${HNG_USERNAME:-Your-Username}"
```

**What happens:**
1. First `$$` - Bash expands to process ID (2917558)
2. Then `${HNG_USERNAME:-...}` - Tries to use variable
3. But HNG_USERNAME not set in bash → uses default
4. Result: `2917558{HNG_USERNAME:-Your-Username}`

**Why this happened:**
- Script is generated by Terraform `templatefile()`
- `templatefile()` uses `${variable}` syntax (single $)
- But script also uses bash variable substitution `${var}` (also single $)
- Conflict: How to write literal `${VAR}` when `templatefile()` uses same syntax?
- Solution: Use `$$$` to escape it for `templatefile()`
- But this caused bash to interpret `$$` as process ID

### Debugging Process

**Step 1: SSH to instance**
```bash
ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@100.25.222.228
```

**Step 2: Check user data script**
```bash
sudo cat /usr/local/bin/update-nginx-ssl.sh
# Saw: HNG_USERNAME="$$${HNG_USERNAME:-Your-Username}"
```

**Step 3: Understand the syntax**
- `$$$` should mean: first `$$` escapes to `$`, then `${}` is literal
- But bash interprets `$$` as process ID before the escape can happen
- This is a `templatefile()` syntax issue

**Step 4: Test the fix**
```bash
HNG_USERNAME="Timileyin-Your-Cloud/DevOps-Guy"
# Update script to use: $HNG_USERNAME (single $ + braces)
# This way templatefile() substitutes correctly
```

### Solution Implemented

**In user_data.sh, changed:**
```bash
# ❌ WRONG
HNG_USERNAME="$$${HNG_USERNAME:-Your-Username}"

# ✅ CORRECT
HNG_USERNAME="${hng_username}"
# Where hng_username is injected by Terraform templatefile()
```

**Or manually update the script and pass as environment:**
```bash
sudo HNG_USERNAME="Timileyin-Your-Cloud/DevOps-Guy" /usr/local/bin/update-nginx-ssl.sh infra.mosesekerin.name.ng
```

### Lesson Learned
- ✅ `templatefile()` uses `${variable}` syntax
- ✅ Cannot nest bash `${var}` inside `${var}` for template
- ✅ Must carefully distinguish between:
  - Terraform templatefile() variables: `${var_name}`
  - Bash environment variables: `$VAR_NAME`
  - Bash variable expansion: `${variable:-default}`
- ⚠️ Escaping in templates is tricky; avoid when possible
- ⚠️ Test with actual values, not placeholders

---

## Problem 6: SSL Certificate Validation for www Subdomain

### Symptoms Observed
- Running: `sudo certbot certonly --nginx -d infra.mosesekerin.name.ng -d www.infra.mosesekerin.name.ng`
- Certbot fails with: `Domain: www.infra.mosesekerin.name.ng, Type: dns, Detail: DNS problem: NXDOMAIN looking up A for www.infra.mosesekerin.name.ng`
- NXDOMAIN = Non-existent domain

### Root Cause

**The www subdomain was never created in Route53.**

The project only has:
- `infra.mosesekerin.name.ng` → 100.25.222.228 (A record)
- `www.infra.mosesekerin.name.ng` → (missing)

When certbot tries to validate www subdomain, Let's Encrypt looks up:
```
A record for www.infra.mosesekerin.name.ng
```
- Not found (NXDOMAIN)
- Validation fails

### Solution Implemented

**Option 1: Create www DNS record**
```bash
aws route53 change-resource-record-sets ...
# Add: www.infra.mosesekerin.name.ng → 100.25.222.228
```

**Option 2: Certificate for base domain only (implemented)**
```bash
certbot certonly --nginx -d infra.mosesekerin.name.ng
# Only base domain, not www
# Simpler, works fine for single instance
```

### Lesson Learned
- ✅ DNS records must exist before Let's Encrypt validation
- ✅ www subdomain requires separate DNS entry
- ✅ Can use single domain or multi-domain certificates
- ✅ For single-instance, base domain sufficient
- ⚠️ DNS validation requires actual DNS resolution

---

## Problem 7: Nginx Reverse Proxy - Frontend Path Handling

### Symptoms Observed
- Nginx reverse proxy configured to /app
- Browser request: `https://infra.mosesekerin.name.ng/app`
- Response: `<!DOCTYPE html>...<pre>Cannot GET /app</pre>`
- Error coming from frontend app (express error page)

### Root Cause

**Frontend app expects requests at `/`, not `/app`**

The frontend application has routes at:
- `/` (home)
- `/submit` (API endpoint)
- `/status/{id}` (status endpoint)

When Nginx proxies to `/app`, it passes the full path to frontend:
```
GET /app
```
- Frontend has no `/app` route → 404

### Solution Implemented

**Add trailing slash to proxy_pass:**
```nginx
# ❌ WRONG
location /app {
    proxy_pass http://microapp_frontend;
}

# ✅ CORRECT  
location /app {
    proxy_pass http://microapp_frontend/;
    # Trailing slash strips /app before forwarding
}
```

**How it works:**
```
Request: GET /app
→ Nginx sees: /app matches location /app
→ Strips /app (because of trailing /)
→ Forwards to backend: GET /
→ Frontend has / route → 200 OK
```

### Lesson Learned
- ✅ `proxy_pass` with trailing `/` strips the location path
- ✅ `proxy_pass` without trailing `/` appends the location path
- ✅ Must understand the backend app's route structure
- ⚠️ Path rewriting is critical in reverse proxies

---

## Problem 8: Backend Not Exposed to Host

### Symptoms Observed
- Tried to access `https://infra.mosesekerin.name.ng/microapp`
- Got: 502 Bad Gateway
- Nginx error log: `connect() failed (111: Unknown error) while connecting to upstream, upstream: http://127.0.0.1:8000/microapp`
- Port 8000 not responding

### Root Cause

**Docker backend container doesn't expose port 8000 to host.**

The architecture:
- Docker containers in internal network (172.17.0.0/16)
- Backend listens on port 8000 (inside container network)
- Host tries to access 127.0.0.1:8000 (not exposed)
- Connection refused

### Solution Implemented

**Decision: Keep backend internal only (don't expose)**

Reasoning:
- Backend should not be publicly accessible
- Frontend is the gateway to backend
- Better security posture

Changed Nginx config:
```nginx
# ❌ REMOVED
upstream microapp_backend {
    server 127.0.0.1:8000;
}

location /microapp {
    proxy_pass http://microapp_backend;
}

# ✅ ADDED
location / {
    proxy_pass http://microapp_frontend/;
    # Frontend only exposed
}
```

### Lesson Learned
- ✅ Docker containers have separate network namespace
- ✅ Must expose ports explicitly or use service names in same network
- ✅ Microservices architecture: frontend exposes, backend internal
- ⚠️ Don't try to access Docker containers from host by localhost:port
- ⚠️ Use service names within Docker network

---

## Problem-Solving Methodology Used

### Pattern: Systematic Debugging

For each problem, the approach was:

1. **Observe Symptoms**
   - What error messages?
   - When does it occur?
   - What are the conditions?

2. **Form Hypotheses**
   - Multiple possible causes
   - Ranked by likelihood

3. **Test Locally**
   - Reproduce issue in controlled environment
   - Verify fix locally before CI/CD

4. **Isolate Variables**
   - Change one thing at a time
   - Confirm which change fixed it

5. **Root Cause Analysis**
   - Why did it happen?
   - What assumption was wrong?

6. **Document Solution**
   - How to fix it
   - Why this fix works
   - How to prevent in future

### Debugging Tools Used

- GitHub Actions logs (visual inspection)
- `terraform plan` output (local testing)
- `aws iam` commands (permission verification)
- SSH to instance (runtime inspection)
- Nginx error logs (`/var/log/nginx/error.log`)
- Browser developer tools (frontend debugging)
- `curl` for API testing

### Success Metrics

| Problem | Time to Resolve | Root Cause Complexity |
|---------|-----------------|----------------------|
| Terraform hang | 15 min | Medium |
| Output parsing | 20 min | Low |
| Debug metadata | 30 min | High |
| IAM permissions | 25 min | Medium |
| Variable substitution | 40 min | High |
| SSL validation | 10 min | Low |
| Nginx routing | 20 min | Low |
| Docker networking | 15 min | Low |

**Total debugging time:** ~3 hours
**Problems solved:** 8 major issues
**Lessons learned:** 15+

---

## Debugging Lessons for Future Work

### What Worked
- ✅ Testing locally before CI/CD
- ✅ Systematic hypothesis testing
- ✅ Reading actual error messages carefully
- ✅ Checking logs at every layer
- ✅ Understanding each technology deeply

### What to Improve
- ⚠️ Better isolation of terraform variables earlier
- ⚠️ More comprehensive IAM permissions setup upfront
- ⚠️ Better documentation of architecture decisions early
- ⚠️ More extensive local testing before CI/CD

### For Production
- ✅ Monitoring and alerting (prevent issues)
- ✅ Structured logging (faster debugging)
- ✅ Health checks (early detection)
- ✅ Runbooks (quick resolution)
