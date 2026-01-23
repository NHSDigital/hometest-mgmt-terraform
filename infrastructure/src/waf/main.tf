################################################################################
# WAF v2 Web ACL - Main Configuration
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "waf"
  })

  waf_name = "${local.resource_prefix}-waf"
}

################################################################################
# WAF Web ACL
################################################################################

resource "aws_wafv2_web_acl" "main" {
  name        = local.waf_name
  description = "WAF Web ACL for ${local.resource_prefix} API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        dynamic "rule_action_override" {
          for_each = var.common_rules_excluded
          content {
            name = rule_action_override.value
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Linux OS
  dynamic "rule" {
    for_each = var.enable_linux_rules ? [1] : []
    content {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesLinuxRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-linux"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rate Limiting Rule
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 10

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  # IP Allowlist Rule (optional)
  dynamic "rule" {
    for_each = var.enable_ip_allowlist && length(var.allowed_ip_addresses) > 0 ? [1] : []
    content {
      name     = "IPAllowlistRule"
      priority = 0

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowlist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-ip-allowlist"
        sampled_requests_enabled   = true
      }
    }
  }

  # IP Blocklist Rule (optional)
  dynamic "rule" {
    for_each = var.enable_ip_blocklist && length(var.blocked_ip_addresses) > 0 ? [1] : []
    content {
      name     = "IPBlocklistRule"
      priority = 5

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-ip-blocklist"
        sampled_requests_enabled   = true
      }
    }
  }

  # Geo Restriction Rule (optional)
  dynamic "rule" {
    for_each = var.enable_geo_restriction && length(var.allowed_countries) > 0 ? [1] : []
    content {
      name     = "GeoRestrictionRule"
      priority = 6

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.allowed_countries
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-geo-restrict"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.waf_name
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = local.waf_name
  })
}

################################################################################
# IP Sets
################################################################################

resource "aws_wafv2_ip_set" "allowlist" {
  count = var.enable_ip_allowlist && length(var.allowed_ip_addresses) > 0 ? 1 : 0

  name               = "${local.resource_prefix}-ip-allowlist"
  description        = "Allowed IP addresses for ${local.resource_prefix}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_addresses

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-ip-allowlist"
  })
}

resource "aws_wafv2_ip_set" "blocklist" {
  count = var.enable_ip_blocklist && length(var.blocked_ip_addresses) > 0 ? 1 : 0

  name               = "${local.resource_prefix}-ip-blocklist"
  description        = "Blocked IP addresses for ${local.resource_prefix}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.blocked_ip_addresses

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-ip-blocklist"
  })
}

################################################################################
# WAF Association with API Gateway
################################################################################

locals {
  # Skip association if ARN is empty or contains 'mock' (from terragrunt mock_outputs)
  skip_waf_association = var.api_gateway_stage_arn == "" || can(regex("mock", var.api_gateway_stage_arn))
}

resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = local.skip_waf_association ? 0 : 1

  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

################################################################################
# CloudWatch Log Group for WAF Logs
################################################################################

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.resource_prefix}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf.arn

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-waf-logs"
  })
}

################################################################################
# KMS Key for WAF Logs
################################################################################

resource "aws_kms_key" "waf" {
  description             = "KMS key for ${local.resource_prefix} WAF logs"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs access"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-waf-kms"
  })
}

resource "aws_kms_alias" "waf" {
  name          = "alias/${local.resource_prefix}-waf"
  target_key_id = aws_kms_key.waf.key_id
}

################################################################################
# WAF Logging Configuration
################################################################################

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  dynamic "redacted_fields" {
    for_each = var.redacted_fields
    content {
      dynamic "single_header" {
        for_each = redacted_fields.value.type == "single_header" ? [1] : []
        content {
          name = redacted_fields.value.name
        }
      }
    }
  }

  logging_filter {
    default_behavior = var.log_all_requests ? "KEEP" : "DROP"

    # Filter for blocked/counted requests (always present to satisfy minimum requirement)
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }

    # Additional filter for counted requests
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }
}
