# TF_org-user

Creates the `terraform-execute` IAM role in each AWS account. This role has `AdministratorAccess` and trusts the management account to assume it, allowing all Terraform components to run cross-account from a single set of credentials.

## Structure

- `main.tf`: Provider aliases and `terraform_execute_role` module calls — one per account.
- `providers.tf`: Required provider and S3 backend.
- `modules/terraform_execute_role/main.tf`: Creates the IAM role and attaches `AdministratorAccess`.

## Accounts covered

| Provider alias | Account | Notes |
|---------------|---------|-------|
| `org_root` | Management (org root) | **No assume_role** — uses whatever credentials are active in the shell. In Scenario A (IAM user in mgmt account) this is the IAM user directly. In Scenario B (dedicated mgmt account) this is the bootstrap/root credentials. Required so `terraform-execute` exists in the management account for future non-bootstrap runs. |
| `mgmt` | Management OU member account | Assumes `OrganizationAccountAccessRole` |
| `dev` | Dev account | Assumes `OrganizationAccountAccessRole` |
| `network` | Network account | Assumes `OrganizationAccountAccessRole` |
| `prod` | Prod account | Assumes `OrganizationAccountAccessRole` |

## Prerequisites

- Organization and all member accounts must already exist (run `Organization/` first using the bootstrap provider — see `Organization/README.md § Bootstrap`).
- Your AWS credentials must be for the **management account** (the org root account where your IAM user lives).
- `OrganizationAccountAccessRole` must exist in each member account (created automatically by AWS Organizations when accounts are created via Terraform).

## Usage

1. Copy the example and set all account IDs (find them in AWS Console → Organizations → AWS accounts):

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your account IDs
```

2. Run from the management account:

```bash
cd TF_org-user
terraform init
terraform plan
terraform apply
```

3. After apply, `terraform-execute` exists in all accounts. Switch `Organization/` off the bootstrap provider (see `Organization/README.md`).

## Requirements

- Terraform >= 0.12
- AWS provider ~> 5.0

## Why explicit providers instead of a loop?

Terraform requires provider configurations to be static — you can't generate provider aliases dynamically. Each account gets its own explicit `provider` block and module call. This is a known Terraform limitation.
