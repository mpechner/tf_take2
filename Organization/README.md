# AWS Organization Setup

## Prerequisites

**Note:** This configuration assumes you're starting with an existing AWS account, not creating a brand new organization from scratch. If you're starting completely fresh, some additional manual setup steps may be required.

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