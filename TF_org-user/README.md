# TF_org-user

This Terraform module is designed to create and attach an IAM role for Terraform execution in an AWS organization. It uses a provider alias to assume a role in a specific AWS account.

## Structure

- `main.tf`: Defines the provider alias and calls the `terraform_execute_role` module.
- `providers.tf`: Declares the required AWS provider and configures the S3 backend for state storage.
- `modules/terraform_execute_role/main.tf`: Contains the resources to create an IAM role and attach an administrator policy.

## Usage

1. Make sure the Organization plan has run
2. Ensure you have the AWS CLI configured with appropriate credentials.
3. Run `terraform init` to initialize the module and download the required providers.
4. Run `terraform apply` to create the IAM role and attach the policy.

## Requirements

- Terraform version >= 0.12
- AWS provider version ~> 5.0

## Notes

- The module assumes a role in the AWS account specified in the provider configuration.
- The IAM role created has the `AdministratorAccess` policy attached.

## Why Define Each Role and Provider Individually?

In this module, each IAM role and provider is defined individually rather than using a loop due to a limitation in how Terraform handles provider configurations, especially when using provider aliases. Terraform requires explicit provider configurations for each alias, which makes it challenging to use loops or dynamic configurations for providers. This is a known limitation in Terraform's design, and it's why we often see explicit definitions in configurations that need to manage multiple roles or accounts. 