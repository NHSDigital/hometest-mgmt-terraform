################################################################################
# CloudFront SPA Distribution
# Single domain with path-based routing:
# - / -> SPA (S3)
# - /api1/* -> API Gateway 1
# - /api2/* -> API Gateway 2
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

  # API Gateway origins for path-based routing
  api_origins = {
    api1 = {
      domain_name = "${module.api_gateway_1.rest_api_id}.execute-api.${local.region}.amazonaws.com"
      origin_path = "/${var.api_stage_name}"
    }
    api2 = {
      domain_name = "${module.api_gateway_2.rest_api_id}.execute-api.${local.region}.amazonaws.com"
      origin_path = "/${var.api_stage_name}"
    }
  }

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

  tags = var.tags

  depends_on = [
    aws_api_gateway_deployment.api1,
    aws_api_gateway_deployment.api2
  ]
}
