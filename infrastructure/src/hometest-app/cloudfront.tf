################################################################################
# CloudFront SPA Distribution
# Serves the Next.js SPA from S3 at {env}.poc.hometest.service.nhs.uk (POC)
# or a custom domain (e.g., dev.hometest.service.nhs.uk) when create_cloudfront_certificate = true.
# API endpoints are served separately via API Gateway custom domain.
# CF function handles Next.js client-side route fallback (non-file paths → index.html)
################################################################################

locals {
  # When create_cloudfront_certificate = true a dedicated us-east-1 cert is created here;
  # otherwise re-use the shared wildcard cert passed in from shared_services.
  cloudfront_cert_arn = (
    var.create_cloudfront_certificate
    ? try(aws_acm_certificate_validation.cloudfront[0].certificate_arn, null)
    : var.acm_certificate_arn
  )
}

################################################################################
# Per-environment CloudFront ACM Certificate (us-east-1)
# Only created when create_cloudfront_certificate = true.
################################################################################

resource "aws_acm_certificate" "cloudfront" {
  count    = var.custom_domain_name != null && var.create_cloudfront_certificate ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-cloudfront-cert"
  })
}

resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = var.custom_domain_name != null && var.create_cloudfront_certificate ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.custom_domain_name != null && var.create_cloudfront_certificate ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]
}

module "cloudfront_spa" {
  source = "../../modules/cloudfront-spa"

  project_name          = var.project_name
  environment           = var.environment
  aws_account_id        = var.aws_account_id
  aws_account_shortname = var.aws_account_shortname

  enable_spa_routing = true
  price_class        = var.cloudfront_price_class

  s3_kms_key_arn                        = var.kms_key_arn
  s3_noncurrent_version_expiration_days = 30

  # API traffic is now served directly via api-{env}.poc.hometest.service.nhs.uk (API Gateway custom domain).
  # CloudFront serves the SPA only — no API origins or path-based API behaviours needed.
  # enable_spa_routing remains true: the CF function handles Next.js client-side route fallback (→ index.html).
  api_origins = {}

  # Custom domain - SPA domain
  custom_domain_names = var.custom_domain_name != null ? [var.custom_domain_name] : []
  acm_certificate_arn = local.cloudfront_cert_arn
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
