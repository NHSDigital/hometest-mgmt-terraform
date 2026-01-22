################################################################################
# ACM Certificate for API Gateway / CloudFront
################################################################################

resource "aws_acm_certificate" "main" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name               = var.route53_zone_name
  subject_alternative_names = var.acm_subject_alternative_names
  validation_method         = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-cert"
  })
}

################################################################################
# ACM DNS Validation Records
################################################################################

resource "aws_route53_record" "acm_validation" {
  for_each = var.create_acm_certificate ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.main.zone_id
}

################################################################################
# ACM Certificate Validation
################################################################################

resource "aws_acm_certificate_validation" "main" {
  count = var.create_acm_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

################################################################################
# ACM Certificate for CloudFront (must be in us-east-1)
# Note: This requires a separate provider for us-east-1
################################################################################

# Uncomment if using CloudFront - requires provider alias for us-east-1
# resource "aws_acm_certificate" "cloudfront" {
#   count    = var.create_cloudfront_certificate ? 1 : 0
#   provider = aws.us_east_1
#
#   domain_name               = var.route53_zone_name
#   subject_alternative_names = var.acm_subject_alternative_names
#   validation_method         = "DNS"
#
#   lifecycle {
#     create_before_destroy = true
#   }
#
#   tags = merge(local.common_tags, {
#     Name = "${local.resource_prefix}-cloudfront-cert"
#   })
# }
