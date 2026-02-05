################################################################################
# ACM Certificate - Regional (for API Gateway)
################################################################################

resource "aws_acm_certificate" "regional" {
  count = var.create_acm_certificates ? 1 : 0

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-regional-cert"
  })
}

resource "aws_route53_record" "regional_cert_validation" {
  for_each = var.create_acm_certificates ? {
    for dvo in aws_acm_certificate.regional[0].domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "regional" {
  count = var.create_acm_certificates ? 1 : 0

  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for record in aws_route53_record.regional_cert_validation : record.fqdn]
}

################################################################################
# ACM Certificate - Global (for CloudFront - us-east-1)
################################################################################

resource "aws_acm_certificate" "cloudfront" {
  count    = var.create_acm_certificates ? 1 : 0
  provider = aws.us_east_1

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-cloudfront-cert"
  })
}

# Note: DNS validation records are the same as regional, so we don't need to create them again

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.create_acm_certificates ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.regional_cert_validation : record.fqdn]
}
