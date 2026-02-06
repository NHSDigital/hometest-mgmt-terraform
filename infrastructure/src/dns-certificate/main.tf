################################################################################
# DNS Certificate Module - Route53 Records and ACM Certificates
################################################################################

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "dns-certificate"
  })

  # Construct the FQDN for this environment
  environment_fqdn = var.environment == "prod" ? var.base_domain_name : "${var.environment}.${var.base_domain_name}"
}

################################################################################
# Data Source - Existing Route53 Zone
################################################################################

data "aws_route53_zone" "main" {
  name         = var.base_domain_name
  private_zone = false
}

################################################################################
# ACM Certificate
################################################################################

resource "aws_acm_certificate" "main" {
  domain_name               = local.environment_fqdn
  subject_alternative_names = var.additional_domain_names
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
# Route53 Records for Certificate Validation
################################################################################

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

################################################################################
# Certificate Validation
################################################################################

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# Route53 A Record - Alias to API Gateway
################################################################################

resource "aws_route53_record" "api_gateway_alias" {
  count = var.create_api_gateway_record ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.environment_fqdn
  type    = "A"

  alias {
    name                   = var.api_gateway_regional_domain_name
    zone_id                = var.api_gateway_regional_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Route53 Health Check (optional)
################################################################################

resource "aws_route53_health_check" "main" {
  count = var.create_health_check ? 1 : 0

  fqdn              = local.environment_fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-health-check"
  })
}

################################################################################
# CloudWatch Alarm for Health Check
################################################################################

resource "aws_cloudwatch_metric_alarm" "health_check" {
  count = var.create_health_check ? 1 : 0

  alarm_name          = "${local.resource_prefix}-endpoint-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Health check for ${local.environment_fqdn}"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.main[0].id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-health-alarm"
  })
}
