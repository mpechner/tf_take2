# Security Review

**Reviewer:** Senior DevSecOps  
**Date:** 2026-02-28  
**Scope:** Terraform IaC, Ansible automation, OpenVPN TLS sync pipeline, RKE2 cluster EC2 modules  
**Codebase:** `tf_take2`

---

## How to Read This Document

Two separate passes:

- **Part 1 — Short-Lived Dev Environment**: You know this gets destroyed. What are the risks right now, today, while it exists?
- **Part 2 — Production Hardening**: What would have to change before this becomes a real workload?

Severity ratings: `CRITICAL` / `HIGH` / `MEDIUM` / `LOW` / `INFO`

---

## Part 1 — Short-Lived Dev Environment: Risks Right Now

These are findings that matter even for a box you're going to destroy in a week, because they can be exploited or leak data in that window.

---

### SEC-001 — ~~`CRITICAL`~~ `LOW (dev) / CRITICAL (prod)` — SSH Private Key Written to Terraform State in Plaintext

**File:** `openvpn/devvpn/sshkey.tf:5-8`, `RKE-cluster/dev-cluster/ec2/sshkey.tf:1-4`

```hcl
resource "tls_private_key" "openvpn_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

`tls_private_key` writes the private key PEM to Terraform state. Your S3 state bucket (`mikey-com-terraformstate`) holds a readable copy of every SSH private key for every server in this environment. Anyone with `s3:GetObject` on that bucket owns every box.

**Dev environment impact:** `LOW` — single-user account, S3 public access is blocked, no other IAM principals, environment is short-lived. The risk surface is real but the actual exposure is minimal given these constraints.

**If production:** `CRITICAL`. State is append-only — the key persists in state history even after the resource is destroyed. Any IAM principal that gains read access to the state bucket (not just public access) owns every box. In a team environment this is a confirmed breach path. See P-001 for the fix.

**Mitigation (now):** Verify the state bucket has SSE-KMS encryption and that IAM access to it is locked to `terraform-execute` role only. Run `aws s3api get-bucket-encryption --bucket mikey-com-terraformstate` to confirm.

---

### SEC-002 — `CRITICAL` — RKE Node IAM Role Can Read Every Secret in the Account

**File:** `RKE-cluster/modules/ec2/main.tf:196-208`

```hcl
{
  Sid    = "ReadAny"
  Effect = "Allow"
  Action = [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret",
  ]
  Resource = "*"
}
```

Every pod running on any node in the cluster inherits this via the EC2 instance profile. A single RCE in any pod gives an attacker `GetSecretValue` on every secret in the AWS account — RDS passwords, third-party API keys, anything. This is one of the most dangerous privilege escalation paths in AWS.

**Dev environment impact:** Any public-facing workload on the cluster is a potential path to full-account secret exfiltration.

**Mitigation (now):** Scope this to `arn:aws:secretsmanager:us-west-2:REDACTED_ACCOUNT_ID:secret:rke/*` and `arn:aws:secretsmanager:us-west-2:REDACTED_ACCOUNT_ID:secret:openvpn/*` as a minimum.

---

### SEC-003 — `HIGH` — Hardcoded AWS Account ID in Module

**File:** `RKE-cluster/modules/ec2/main.tf:276, 327`

```bash
--role-arn "arn:aws:iam::REDACTED_ACCOUNT_ID:role/terraform-execute"
```

Account ID `REDACTED_ACCOUNT_ID` is hardcoded in two `local-exec` provisioner scripts. This is your real production account ID, committed to git history permanently. It doesn't expire. Combined with other account enumeration signals in public repos, this narrows the attack surface significantly.

**Dev environment impact:** The account ID is already in two commits. It will be in git history forever unless a rewrite is done.

**Mitigation (now):** Replace with `data "aws_caller_identity" "current" {}` and reference `data.aws_caller_identity.current.account_id`.

---

### SEC-004 — `HIGH` — TLS Cert and Private Key Written to `/tmp` During Sync

**File:** `openvpn/ansible/openvpn-tls-sync.yml:97, 110`

```bash
} > /tmp/new_cert.crt
} > /tmp/new_key.key
```

The private key for the VPN TLS certificate is written to `/tmp` on the OpenVPN server during every sync run. `/tmp` is world-readable by default on most Linux systems. Any process running on the server — including the OpenVPN process itself, any user session, or a future compromised process — can read the key before or during the sync window.

**Dev environment impact:** The key lands on disk in cleartext in `/tmp` every 30 minutes.

**Mitigation (now):** Use a `mktemp -d` to create a 0700 temp directory, write files there, and `rm -rf` the directory in a `trap EXIT`. Or pipe directly to `sacli` without touching disk at all.

---

### SEC-005 — `HIGH` — Route53 `ChangeResourceRecordSets` Falls Back to `*`

**File:** `RKE-cluster/modules/ec2/main.tf:250`

```hcl
Resource = length(var.route53_hosted_zone_ids) > 0
  ? [for id in var.route53_hosted_zone_ids : "arn:aws:route53:::hostedzone/${id}"]
  : ["*"]
```

If `route53_hosted_zone_ids` is not passed (it defaults to `[]`), every node in the cluster can mutate DNS records in every hosted zone in the account. This means a compromised pod can redirect any domain you own. The variable default makes the dangerous path the easy path.

**Dev environment impact:** Check whether `route53_hosted_zone_ids` is actually being passed in `RKE-cluster/dev-cluster/ec2/`. If not, this is open right now.

**Mitigation (now):** Change the default to fail loudly: `type = list(string)` with no default, or validate `length(var.route53_hosted_zone_ids) > 0` with a precondition.

---

### SEC-006 — `MEDIUM` — Ansible Pulls AWS CLI from the Internet at Runtime

**File:** `openvpn/ansible/openvpn-tls-sync.yml:30-35`

```bash
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q -o awscliv2.zip
./aws/install --update
```

The sync playbook downloads and installs AWS CLI directly from the internet without verifying a checksum or signature. A DNS hijack or CDN compromise during the setup window yields arbitrary code execution as root on the VPN server.

**Dev environment impact:** Happens once per `terraform apply`. The install is complete now; the next run of the playbook re-executes only if `aws_cli_check` indicates a missing or v1 CLI.

**Mitigation (now):** Add checksum verification. The official AWS CLI installer publishes a PGP signature. At minimum: `curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sha256 -o awscliv2.sha256 && sha256sum -c awscliv2.sha256`.

---

### SEC-007 — `MEDIUM` — `recovery_window_in_days = 0` on All Secrets

**Files:** `openvpn/devvpn/sshkey.tf:13`, `RKE-cluster/dev-cluster/ec2/sshkey.tf:9`

```hcl
recovery_window_in_days = 0
```

Immediate deletion on `terraform destroy`. This is intentional for a dev environment (no 30-day hold) but it means accidental destruction of the secret is instant and unrecoverable. This also suppresses the normal guardrail against naming conflicts in Secrets Manager, allowing silent overwrite on re-apply.

**Dev environment impact:** Acceptable for dev. Flag for prod.

---

### SEC-008 — `MEDIUM` — OpenVPN Admin UI (Port 943) and HTTP (Port 80) Open to Dynamic IP Detection

**File:** `openvpn/devvpn/main.tf:4-10`, `openvpn/module/main.tf:104-120`

```hcl
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}
local.admin_ip = var.comcast_ip != "" ? var.comcast_ip : "${local.my_ip}/32"
```

Admin access (ports 22, 80, 943) is scoped to your detected IP — good. But `icanhazip.com` is a third-party service. If it returns an incorrect IP (misconfiguration, brief hijack, or the variable `comcast_ip` is left blank after an ISP change), your rules could end up with the wrong CIDR. There's no validation that `local.my_ip` is actually a valid IPv4 address before appending `/32`.

**Dev environment impact:** Low — `icanhazip.com` is reliable. But worth noting.

---

### SEC-009 — `LOW` — `null_resource` TLS Sync Failure is Silenced

**File:** `openvpn/devvpn/main.tf:115`

```bash
AUTO_APPROVE=1 ./"$(basename "$ANSIBLE_SCRIPT")" || true
```

The `|| true` at the end means Ansible playbook failures are silently swallowed. `terraform apply` will succeed even if the TLS sync setup completely failed. You won't know unless you manually check the output.

**Dev environment impact:** Operational risk. Cert sync may not be installed but Terraform reports success.

---

## Part 2 — Production Hardening

These are the architectural and design changes required before any version of this becomes a production workload.

---

### P-001 — `CRITICAL` — Eliminate `tls_private_key` from Terraform State

**Files:** `openvpn/devvpn/sshkey.tf`, `RKE-cluster/dev-cluster/ec2/sshkey.tf`

`tls_private_key` is a known anti-pattern for production. Private keys live in state forever, even after the resource is destroyed, because state is append-only until pruned. For production:

- **SSH keys:** Generate out-of-band (e.g., `ssh-keygen` in a CI pipeline) and inject the public key only. Store the private key in a secrets vault (HashiCorp Vault, AWS Secrets Manager) that Terraform never reads back.
- **Or:** Use AWS Systems Manager Session Manager + IAM for all administrative access and eliminate SSH entirely. No key to manage.

---

### P-002 — `CRITICAL` — Scope IAM Policies to Least Privilege

Three policies need rewriting for production:

**RKE nodes Secrets Manager (`ec2/main.tf:196-208`):**
The `Resource = "*"` on `GetSecretValue` must be replaced with explicit ARN prefixes. The real fix is IRSA (IAM Roles for Service Accounts) so each workload gets its own scoped role, not a shared node role.

**RKE nodes Route53 (`ec2/main.tf:244-254`):**
The fallback-to-`*` pattern must be removed. `route53_hosted_zone_ids` must be required, and a precondition should enforce it.

**OpenVPN KMS (`openvpn/module/main.tf:68-74`):**
```hcl
Resource = "arn:aws:kms:*:*:key/*"
```
This allows the OpenVPN instance to use any KMS key in the account for decryption. Scope to the specific key ARN used to encrypt the TLS secret.

---

### P-003 — `CRITICAL` — Replace Node-Level IAM with IRSA for Kubernetes Workloads

**File:** `RKE-cluster/modules/ec2/main.tf:191-254`, `RKE-cluster/modules/server/iam.tf`

The cert-manager, external-dns, and openvpn-cert-publisher CronJob all inherit permissions from the EC2 node IAM role. This is a blast-radius problem: compromise of one pod can be used to access AWS APIs with permissions intended for a different pod.

IRSA (the OIDC-based IAM role binding already partially scaffolded in `server/iam.tf`) is the correct solution. Each Kubernetes workload gets its own IAM role. The node role should have near-zero AWS permissions.

**Note:** The OIDC URL in `server/iam.tf:59` — `https://oidc.<cluster_name>.<region>.amazonaws.com` — is not a real OIDC issuer URL for RKE2. RKE2 generates its own JWKS endpoint; you need to either use `kube-oidc-proxy` or set `kube-apiserver-arg: ["service-account-issuer=https://..."]` in RKE2 config and host the discovery document in S3. This must be resolved before IRSA will work.

---

### P-004 — `HIGH` — Encrypt EBS Volumes at Rest

**File:** `RKE-cluster/modules/ec2/main.tf:104, 143`

```hcl
root_block_device {
  encrypted = false
}
```

Both server and agent node root volumes are unencrypted. For production, all EBS volumes must be encrypted. Enable the AWS account-level default encryption (`aws_ebs_encryption_by_default`) to enforce this as a guardrail, and set `encrypted = true` with an explicit `kms_key_id` pointing to a customer-managed key.

The OpenVPN server (`openvpn/module/main.tf:146`) correctly has `encrypted = true` — apply the same to RKE nodes.

---

### P-005 — `HIGH` — TLS Private Key Must Not Touch Disk in `/tmp`

**File:** `openvpn/ansible/openvpn-tls-sync.yml:97-116`

In production, the cert sync script needs a rewrite of the key-handling section:

```bash
# Replace this pattern:
} > /tmp/new_key.key

# With:
TMPDIR=$(mktemp -d --tmpdir=/root 2>/dev/null || mktemp -d)
chmod 700 "$TMPDIR"
trap "rm -rf $TMPDIR" EXIT
} > "$TMPDIR/new_key.key"
chmod 600 "$TMPDIR/new_key.key"
```

Even better: pipe the key directly into `sacli` via stdin using a process substitution, eliminating the temp file entirely. OpenVPN AS's `sacli ConfigPut --value` flag accepts a value directly; explore whether it can read from a file descriptor rather than a named path.

---

### P-006 — `HIGH` — Hardcoded Account ID and Region Must Be Parameterized

**File:** `RKE-cluster/modules/ec2/main.tf:276, 327, 339`

```bash
arn:aws:iam::REDACTED_ACCOUNT_ID:role/terraform-execute
--region us-west-2
```

For production, these must be:
- Account ID: `data "aws_caller_identity" "current" {}` → `data.aws_caller_identity.current.account_id`
- Region: `data "aws_region" "current" {}` → `data.aws_region.current.name`
- Role name: a variable, not a constant

This also makes the module reusable across accounts (e.g., DR in `us-east-2`).

---

### P-007 — `HIGH` — State Backend Requires Explicit Security Controls

**File:** All `terraform.tf` files with `backend "s3"` blocks

The S3 + DynamoDB backend is correct, but for production the bucket requires:

1. **SSE-KMS** with a customer-managed key (not SSE-S3). State contains private keys (SEC-001), tokens, and passwords.
2. **S3 Bucket Policy** denying `s3:GetObject` to everyone except the `terraform-execute` role and any CI role.
3. **S3 Access Logging** to a separate audit bucket.
4. **Object versioning** (probably already on, but verify) with a lifecycle rule to retain 90 days of state history.
5. **MFA Delete** on the state bucket.
6. **DynamoDB table encryption** with KMS.

---

### P-008 — `HIGH` — Remove Direct SSH Access; Use SSM Session Manager

**Files:** `openvpn/module/main.tf:87-93`, `RKE-cluster/modules/ec2/main.tf:6-11`

In production, SSH ports should not be open at all — not even to admin CIDRs. The attack surface of a listening `sshd` on a public IP is never zero. Instead:

- **RKE nodes:** Already have `AmazonSSMManagedInstanceCore` attached. Use `aws ssm start-session` for all access. Remove `key_name` from instances and close port 22.
- **OpenVPN server:** Port 22 is used by Ansible during `terraform apply`. Replace the Ansible provisioner with cloud-init / user_data that pulls configuration from Secrets Manager on boot. Eliminate the SSH provisioner entirely.

---

### P-009 — `MEDIUM` — AWS CLI Installation Needs Pin and Verification

**File:** `openvpn/ansible/openvpn-tls-sync.yml:29-36`

For production, the AWS CLI installation must be:

1. **Pinned to a specific version** — not `--update` to latest.
2. **Signature-verified** via the official PGP key before execution.
3. **Ideally baked into the AMI** (via Packer or a custom AMI pipeline) so runtime internet access is not required at all. The OpenVPN instance should be able to operate with outbound internet access restricted to the VPC endpoints for Secrets Manager and STS.

---

### P-010 — `MEDIUM` — `allow_overwrite = true` on Route53 Record

**File:** `openvpn/module/main.tf:182`

```hcl
allow_overwrite = true
```

In production this is a footgun. If the VPN hostname already exists (e.g., the previous deployment wasn't fully destroyed), Terraform silently overwrites it. This could redirect live VPN traffic during a partial deployment. Remove `allow_overwrite` and let Terraform fail explicitly if the record exists.

---

### P-011 — `MEDIUM` — Secrets Manager Recovery Window Suppression

**Files:** `openvpn/devvpn/sshkey.tf:13`, `RKE-cluster/dev-cluster/ec2/sshkey.tf:9`

```hcl
recovery_window_in_days = 0
```

Acceptable for dev. For production, set `recovery_window_in_days = 30` (the default). Pair with resource tagging so automated cost/compliance tooling can distinguish dev secrets (immediate delete OK) from prod secrets (recovery window required).

---

### P-012 — `MEDIUM` — CronJob Publisher Uses Node IAM Role, Not IRSA

**File:** `deployments/modules/tls-issue/main.tf:168-237`

The cert-publisher CronJob has a properly scoped Kubernetes RBAC Role (read-only on the TLS secret in `openvpn-certs` namespace), but it calls the AWS Secrets Manager API using the EC2 node's instance profile. For production, give the `openvpn-cert-publisher` ServiceAccount a dedicated IAM role via IRSA, scoped to `secretsmanager:PutSecretValue` on `arn:aws:secretsmanager:*:*:secret:openvpn/*` only. Remove the write permission from the node role entirely.

---

### P-013 — `MEDIUM` — No VPC Flow Logs Alerting

The VPC module enables flow logs to CloudWatch (good). But there is no CloudWatch Metric Filter or Alarm wired to detect:
- SSH attempts from unexpected CIDRs
- Traffic to port 22 on the OpenVPN server from non-admin IPs
- Large data transfers from RKE nodes (potential data exfiltration)

For production, add a `aws_cloudwatch_log_metric_filter` and corresponding alarms, or ship flow logs to a SIEM.

---

### P-014 — `LOW` — `imagePullPolicy: IfNotPresent` on Cert Publisher

**File:** `deployments/modules/tls-issue/main.tf:197`

```hcl
imagePullPolicy = "IfNotPresent"
```

Fine for dev. For production, use `Always` on any security-sensitive container (the cert publisher handles private keys and AWS credentials). This ensures the image is never stale and that a compromised cached image layer is not silently used.

---

### P-015 — `LOW` — `null_resource` Provisioner Errors Must Propagate

**File:** `openvpn/devvpn/main.tf:115`

```bash
AUTO_APPROVE=1 ./"$(basename "$ANSIBLE_SCRIPT")" || true
```

`|| true` silences all Ansible failures. For production, remove this and let the provisioner fail loudly. Pair with a `on_failure = fail` (the Terraform default) so a failed provisioner surfaces as a plan failure, not a quiet warning in logs.

---

## Summary Table

| ID | Severity | Area | Short Description |
|----|----------|------|-------------------|
| SEC-001 | LOW (dev) / CRITICAL (prod) | Secrets | SSH private keys in Terraform state — low risk single-user/short-lived, critical for team/prod |
| SEC-002 | CRITICAL | IAM | Node role reads all secrets (`Resource = "*"`) |
| SEC-003 | HIGH | Secrets | Account ID `REDACTED_ACCOUNT_ID` hardcoded in git |
| SEC-004 | HIGH | Crypto | TLS private key written to `/tmp` during sync |
| SEC-005 | HIGH | IAM | Route53 falls back to `Resource = "*"` when zone IDs not provided |
| SEC-006 | MEDIUM | Supply Chain | AWS CLI downloaded without checksum verification |
| SEC-007 | MEDIUM | Ops | `recovery_window_in_days = 0` on all secrets |
| SEC-008 | MEDIUM | Network | Admin IP detection via third-party service, no validation |
| SEC-009 | LOW | Ops | Ansible failures silenced with `\|\| true` |
| P-001 | CRITICAL | Secrets | Eliminate `tls_private_key` from Terraform state |
| P-002 | CRITICAL | IAM | Scope all IAM policies to least privilege |
| P-003 | CRITICAL | IAM | Replace node-level IAM with IRSA for k8s workloads |
| P-004 | HIGH | Storage | EBS volumes unencrypted on RKE nodes |
| P-005 | HIGH | Crypto | TLS private key must not touch `/tmp` in prod |
| P-006 | HIGH | Config | Remove hardcoded account ID and region from module |
| P-007 | HIGH | State | State backend requires SSE-KMS, bucket policy, audit logging |
| P-008 | HIGH | Network | Replace SSH with SSM Session Manager; close port 22 |
| P-009 | MEDIUM | Supply Chain | Pin and signature-verify AWS CLI; bake into AMI |
| P-010 | MEDIUM | DNS | Remove `allow_overwrite` on Route53 record |
| P-011 | MEDIUM | Secrets | Set `recovery_window_in_days = 30` in production |
| P-012 | MEDIUM | IAM | Give cert-publisher CronJob its own IRSA role |
| P-013 | MEDIUM | Monitoring | Add VPC flow log alerting / SIEM integration |
| P-014 | LOW | K8s | Use `imagePullPolicy: Always` on security-sensitive containers |
| P-015 | LOW | Ops | Remove `\|\| true` from provisioner; propagate failures |

---

## Prioritized Action List

**Do before this dev env is used for anything sensitive:**
1. SEC-002 — Scope Secrets Manager policy on node role
2. SEC-005 — Pass explicit zone IDs or add precondition
3. SEC-004 — Fix `/tmp` key handling in sync script

**Do before any production deployment:**
1. P-001 — Eliminate private keys from Terraform state
2. P-002/P-003 — Full IAM least-privilege + IRSA
3. P-004 — EBS encryption on all volumes
4. P-006 — Parameterize account ID and region
5. P-007 — Harden state backend
6. P-008 — Remove SSH; move to SSM
