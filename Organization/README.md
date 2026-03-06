# AWS Organization Setup

## Prerequisites

This configuration assumes you're starting with an existing AWS account that will become the **org management account** — the AWS account that owns the Organization, controls SCPs, and manages billing.

> **STS note:** Organization Terraform uses `us-east-1` as the provider region. STS regional endpoints may not be activated in all regions for the management account. AWS Organizations is a global service so this has no effect on the resources managed.

---

## Architectural Note: This Repo's Setup vs. AWS Best Practice

**AWS best practice:** The org management account should be a dedicated, minimal-use account — no IAM users, no workloads. Human and automation access should go through IAM Identity Center (SSO) from a separate identity/management account, with the org management account used only for SCPs and billing.

**What this repo does instead:** The org management account (`990880295272`) is also the account where the operator IAM user lives and where org-level Terraform runs. This happened because the AWS Organization was created from an existing account — and the **management account cannot be changed after creation**.

This has two consequences that affect the bootstrap flow:

1. **Security:** Covered in [ARCH-001 in SECURITY-REVIEW.md](../SECURITY-REVIEW.md).
2. **Bootstrap:** The bootstrap provider works by using direct IAM user credentials in the management account. In a properly-designed org (dedicated mgmt account, no IAM users), you'd use the root account credentials or a break-glass IAM user just for initial setup.

See **"Bootstrap Scenario B"** below if you're implementing this correctly with a dedicated management account.

---

## Bootstrap (chicken-and-egg)

Organization Terraform normally assumes `terraform-execute` in the management account. That role is created by **TF_org-user** — but TF_org-user needs the Organization and member accounts to already exist. Neither can run first without credentials that bypass the assume_role requirement.

---

### Scenario A: IAM user lives in the management account (this repo's setup)

Your operator IAM user is in the same account as the org management account. The bootstrap provider uses those credentials directly.

**Step 1: Bootstrap Organization**

```bash
cd Organization
cp providers.tf providers.tf.with-assume
cp providers.tf.bootstrap.example providers.tf
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set management_account_id to your account ID
# (aws sts get-caller-identity → Account)
terraform init -reconfigure
terraform plan
terraform apply   # creates org, OUs, member accounts
cd ..
```

**Step 2: Create terraform-execute in all accounts**

```bash
cd TF_org-user
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set all account IDs
# (find them in AWS Console → Organizations → AWS accounts)
terraform init
terraform plan
terraform apply
cd ..
```

**Step 3: Switch Organization to the normal provider**

```bash
cd Organization
mv providers.tf.with-assume providers.tf
terraform init -reconfigure
terraform plan   # now assumes terraform-execute in the management account
cd ..
```

---

### Scenario B: Dedicated management account (AWS best practice)

The org management account is a dedicated empty account. Your operator credentials are in a separate account (or via SSO). No IAM users exist in the management account.

**Before running Terraform:** You need a way to authenticate to the management account for the initial setup. Options:
- **Root account credentials** (break-glass only — use MFA, rotate after)
- **A one-time bootstrap IAM user** in the management account (delete after setup)
- **AWS CloudShell** in the management account console (uses console session, no long-term credentials)

**Step 1: Bootstrap Organization** (using root or bootstrap IAM user credentials for the management account)

```bash
cd Organization
cp providers.tf providers.tf.with-assume
cp providers.tf.bootstrap.example providers.tf
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set management_account_id to the dedicated mgmt account ID
# Export credentials for the management account:
export AWS_ACCESS_KEY_ID=...     # bootstrap IAM user in mgmt account
export AWS_SECRET_ACCESS_KEY=...
terraform init -reconfigure
terraform apply   # creates org, OUs, member accounts
cd ..
```

**Step 2: Create terraform-execute in all accounts**

TF_org-user's `org_root` provider uses **no assume_role** — it uses your current credentials directly. Make sure you're still authenticated to the management account:

```bash
cd TF_org-user
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set all account IDs
terraform init
terraform apply
cd ..
```

**Step 3: Switch Organization to the normal provider and clean up**

```bash
cd Organization
mv providers.tf.with-assume providers.tf
# Set management_account_id in terraform.tfvars
terraform init -reconfigure
terraform plan   # now assumes terraform-execute — no longer needs root/bootstrap credentials
cd ..
```

Delete the bootstrap IAM user from the management account. All future access goes through `terraform-execute` (assumed from your operator account via the trust policy).

---

## terraform.tfvars

Copy the example and set your management account ID:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit: set management_account_id to the org management account
# Run: aws sts get-caller-identity to find your current account ID
```

---

## What This Creates

- AWS Organization structure
- OUs: prod, dev, management
- Member accounts: Prod, Dev, Management, Network
- Service Control Policy restricting to approved regions
- Cross-account IAM roles for Terraform execution (via TF_org-user)

## Manual Steps Required

### 1. IAM Identity Center Setup

From your management account:
1. Navigate to IAM Identity Center in the AWS Console
2. Enable the service
3. Configure user access and permissions

### 2. Account Security Setup

For each created account, configure via the AWS Console:
- Set root account password
- Enable MFA on root account
- Configure account contact information

## Deploy (normal flow, after bootstrap complete)

```bash
cd Organization
# terraform.tfvars must have management_account_id set
terraform init
terraform plan
terraform apply
```

## After Deployment

`terraform-execute` is available in all accounts, allowing cross-account Terraform deployments assumed from the management account.
