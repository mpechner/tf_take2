output "org-id" {
  value = aws_organizations_organization.org.id
}
output "org-arn" {
  value = aws_organizations_organization.org.arn
}
output "org-root-arn" {
  value = aws_organizations_organization.org.roots[0].arn
}
output "org-root-id" {
  value = aws_organizations_organization.org.roots[0].id
}
output "org-unit-dev-id" {
  value = aws_organizations_organizational_unit.dev.id
}
output "org-unit-dev-name" {
  value = aws_organizations_organizational_unit.dev.name
}
output "org-unit-dev-arn" {
  value = aws_organizations_organizational_unit.dev.arn
}

output "org-unit-prod-id" {
  value = aws_organizations_organizational_unit.prod.id
}
output "org-unit-prod-name" {
  value = aws_organizations_organizational_unit.prod.name
}
output "org-unit-prod-arn" {
  value = aws_organizations_organizational_unit.prod.arn
}

output "org-unit-management-id" {
  value = aws_organizations_organizational_unit.management.id
}
output "org-unit-management-name" {
  value = aws_organizations_organizational_unit.management.name
}
output "org-unit-management-arn" {
  value = aws_organizations_organizational_unit.management.arn
}
