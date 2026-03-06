# AWS Organization Setup

## Prerequisites

**Note:** This configuration assumes you're starting with an existing AWS account, not creating a brand new organization from scratch. If you're starting completely fresh, some additional manual setup steps may be required.

## Bootstrap (chicken-and-egg)

Organization Terraform normally assumes the `terraform-execute` role in the management account. That role is created by **TF_org-user**, which itself assumes `OrganizationAccountAccessRole` in each account — and those roles exist only after the Organization and member accounts exist.

So the typical order is:

1. **First time:** Run Organization Terraform using **default credentials** in the management account (no assume role) — e.g. root or an IAM user in the management account with Organizations permissions. Use the bootstrap provider config (see below) so there is no `assume_role` block.
2. **Then:** Run **TF_org-user** (from the management account, assuming `OrganizationAccountAccessRole` in mgmt) to create `terraform-execute` in the management account (and in dev, prod, network if desired).
3. **After that:** Run Organization Terraform with `management_account_id` set so the provider assumes `terraform-execute` in the management account.

If you already created the Organization before introducing TF_org-user, you were using step 1. To run Organization again now, either use the bootstrap provider (default creds) or ensure `terraform-execute` exists in the management account and set `management_account_id` in `terraform.tfvars`.

**Using the bootstrap provider (no assume role):** Use when `terraform-execute` does not exist in the management account yet. Replace `providers.tf` with the bootstrap version, then restore it after TF_org-user has created the role:

```bash
cp providers.tf providers.tf.with-assume
cp providers.tf.bootstrap.example providers.tf
terraform init -reconfigure
terraform plan   # or apply
# After TF_org-user has created terraform-execute in mgmt:
mv providers.tf.with-assume providers.tf
# Set management_account_id in terraform.tfvars for future runs
```

## What This Creates

This Terraform configuration sets up:
- AWS Organization structure
- Multiple AWS accounts (primary, DR environments)
- Service Control Policies (SCPs) to restrict regions
- Cross-account IAM roles for Terraform execution

## Manual Steps Required

### 1. IAM Identity Center Setup

From your management account:
1. Navigate to IAM Identity Center in the AWS Console
2. Enable the service
3. Configure user access and permissions

### 2. Account Security Setup

For each created account, configure via the AWS Console:
- Set root account password
- Enable MFA (Multi-Factor Authentication) on root account
- Configure account contact information

## Deploy

```bash
cd Organization
terraform init
terraform apply
```

## After Deployment

The Terraform execute role will be available in each account, allowing cross-account deployments from your management account.