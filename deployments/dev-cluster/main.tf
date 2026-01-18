module "ingress" {
  source = "../../modules/ingress"

  aws_region       = var.aws_region
  route53_zone_id  = var.route53_zone_id
  route53_domain   = var.route53_domain
  route53_assume_role_arn = var.route53_assume_role_arn

  letsencrypt_email       = var.letsencrypt_email
  letsencrypt_environment = var.letsencrypt_environment

  ingresses = var.ingresses
}

# Nginx sample site
module "nginx_sample" {
  source = "./modules/nginx-sample"

  namespace      = "nginx-sample"
  environment    = var.environment
  domain         = var.route53_domain
  hostname       = "www.${var.route53_domain}"
  cluster_issuer = "letsencrypt-${var.letsencrypt_environment}"

  depends_on = [module.ingress]
}
