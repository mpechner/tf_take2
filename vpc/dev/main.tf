module "dev" {
  source = "../modules/vpc"
  region = var.region
  name   = var.name
  vpc_cidr = var.vpc_cidr
  azs    = var.azs
  private_subnets     = var.private_subnets
  private_subnet_names = var.private_subnet_names
  public_subnets      = var.public_subnets
  public_subnet_names = var.public_subnet_names
  db_subnets          = var.db_subnets
  db_subnet_names     = var.db_subnet_names

  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway

  # VPC endpoints for Lambda/private workloads (no NAT). Set enable_vpc_endpoints = true and pass Lambda SG id(s).
  enable_vpc_endpoints   = var.enable_vpc_endpoints
  endpoint_subnet_ids    = var.endpoint_subnet_ids
  private_route_table_ids = var.private_route_table_ids
  allowed_source_sg_ids  = var.allowed_source_sg_ids
  tags                   = var.tags
  vpc_endpoint_services_interface = var.vpc_endpoint_services_interface
  vpc_endpoint_services_gateway   = var.vpc_endpoint_services_gateway
}

# ------------------------------------------------------------------------------
# DESTROY: Delete Kubernetes-managed security groups that block VPC deletion.
#
# When Traefik/Kubernetes provisions NLBs, AWS creates security groups with
# names like "k8s-traffic-*" and "k8s-traefik-*" inside the VPC. These are
# not in Terraform state so Terraform cannot delete them, but AWS refuses to
# delete the VPC while non-default security groups still exist.
#
# This null_resource is destroyed BEFORE the VPC module so the k8s-managed
# security groups are gone by the time Terraform calls DeleteVpc.
# ------------------------------------------------------------------------------
resource "null_resource" "pre_destroy_k8s_security_groups" {
  triggers = {
    vpc_cidr   = var.vpc_cidr
    region     = var.region
    account_id = var.account_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -euo pipefail
      REGION="${self.triggers.region}"
      ACCOUNT_ID="${self.triggers.account_id}"
      VPC_CIDR="${self.triggers.vpc_cidr}"

      echo "Assuming OrganizationAccountAccessRole..."
      CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::$ACCOUNT_ID:role/OrganizationAccountAccessRole" \
        --role-session-name "tf-destroy-k8s-sg-cleanup" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
      export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
      export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
      export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')

      VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
        --filters "Name=cidr,Values=$VPC_CIDR" \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

      if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
        echo "VPC not found. Skipping security group cleanup."
        exit 0
      fi

      echo "Found VPC: $VPC_ID — scanning for Kubernetes-managed security groups..."

      # Find all non-default SGs whose name starts with k8s- (created by the
      # AWS cloud-provider / load balancer controller for NLBs and services).
      K8S_SGS=$(aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?starts_with(GroupName, `k8s-`)].GroupId' \
        --output text 2>/dev/null || echo "")

      if [ -z "$K8S_SGS" ]; then
        echo "No Kubernetes-managed security groups found. Nothing to clean up."
        exit 0
      fi

      echo "Found Kubernetes-managed security groups: $K8S_SGS"

      for SG_ID in $K8S_SGS; do
        echo "  Deleting security group $SG_ID..."
        aws ec2 delete-security-group --region "$REGION" \
          --group-id "$SG_ID" 2>/dev/null && echo "  Deleted $SG_ID" \
          || echo "  Could not delete $SG_ID (may have dependencies — retrying after 10s)"
      done

      # One retry pass — SGs with mutual references need two passes.
      sleep 10
      for SG_ID in $K8S_SGS; do
        aws ec2 delete-security-group --region "$REGION" \
          --group-id "$SG_ID" 2>/dev/null || true
      done

      echo "Kubernetes security group cleanup complete."
    EOT
  }

  depends_on = [module.dev]
}
