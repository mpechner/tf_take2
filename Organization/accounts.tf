# because "The provider hashicorp/aws does not support resource type aws_organizations_policy_type."
# Run the following command
#aws organizations enable-policy-type \
#  --root-id r-u7bj \
#  --policy-type SERVICE_CONTROL_POLICY
# aws organizations enable-policy-type   --root-id r-u7bj   --policy-type SERVICE_CONTROL_POLICY

resource "aws_organizations_policy" "region_restriction" {
  name        = "AllowOnlyApprovedRegions"
  description = "Restrict region usage to specific approved regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = file("${path.module}/scp_policies/allow-only-approved-regions.json")
}

resource "aws_organizations_organization" "org" {
  feature_set = "ALL"
  aws_service_access_principals = ["sso.amazonaws.com", "cloudtrail.amazonaws.com", "config.amazonaws.com", "ram.amazonaws.com", "tagpolicies.tag.amazonaws.com", "ipam.amazonaws.com"]
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  lifecycle {
    prevent_destroy = true
  }
}

# PROD OU
resource "aws_organizations_organizational_unit" "prod" {
  name = "prod"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "attach_to_prod" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.prod.id
}

resource "aws_organizations_account" "prod" {
  name      = "ProdAccount"
  email     = "aws-prod@ne6rd.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.prod.id
}

# DEV OU
resource "aws_organizations_organizational_unit" "dev" {
  name = "dev"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "attach_to_dev" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.dev.id
}

resource "aws_organizations_account" "dev" {
  name      = "DevAccount"
  email     = "aws-dev@ne6rd.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.dev.id
}

# management OU 
resource "aws_organizations_organizational_unit" "management" {
  name = "management"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "attach_to_mgmt" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.management.id
}

resource "aws_organizations_account" "management" {
  name      = "ManagementAccount"
  email     = "aws-management@ne6rd.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.management.id
}

resource "aws_organizations_account" "network" {
  name      = "NetworkAccount"
  email     = "aws-network@ne6rd.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.management.id
}