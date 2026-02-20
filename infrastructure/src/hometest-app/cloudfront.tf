################################################################################
# CloudFront SPA Distribution
# Serves the Next.js SPA from S3 at dev.hometest.service.nhs.uk
# API endpoints are served separately at api.dev.hometest.service.nhs.uk (API Gateway custom domain)
# CF function handles Next.js client-side route fallback (non-file paths → index.html)
################################################################################

module "cloudfront_spa" {
  source = "../../modules/cloudfront-spa"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = var.aws_account_id

  enable_spa_routing = true
  price_class        = var.cloudfront_price_class

  s3_kms_key_arn                        = var.kms_key_arn
  s3_noncurrent_version_expiration_days = 30

  # API traffic is now served directly via api.{env}.hometest.service.nhs.uk (API Gateway custom domain).
  # CloudFront serves the SPA only — no API origins or path-based API behaviours needed.
  # enable_spa_routing remains true: the CF function handles Next.js client-side route fallback (→ index.html).
  api_origins = {}

  # Custom domain - single domain for everything
  custom_domain_names = var.custom_domain_name != null ? [var.custom_domain_name] : []
  acm_certificate_arn = var.acm_certificate_arn
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

  tags = local.common_tags
}
