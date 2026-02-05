################################################################################
# CloudFront SPA Distribution
################################################################################

module "cloudfront_spa" {
  source = "../../modules/cloudfront-spa"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = local.account_id

  enable_spa_routing = true
  price_class        = var.cloudfront_price_class

  s3_kms_key_arn                        = var.kms_key_arn
  s3_noncurrent_version_expiration_days = 30

  # No API integration - APIs have separate domains
  api_gateway_domain_name = null

  # Custom domain
  custom_domain_names = var.spa_custom_domain_names
  acm_certificate_arn = var.spa_acm_certificate_arn
  route53_zone_id     = var.route53_zone_id

  # Security
  waf_web_acl_arn         = var.waf_cloudfront_arn
  content_security_policy = var.content_security_policy
  permissions_policy      = var.permissions_policy

  # Geo restriction
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  # Logging
  enable_access_logging      = var.enable_cloudfront_logging
  logging_bucket_domain_name = var.cloudfront_logging_bucket_domain_name

  tags = var.tags
}
