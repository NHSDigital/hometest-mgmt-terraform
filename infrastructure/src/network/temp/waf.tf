################################################################################
# AWS WAF - Web Application Firewall
# Protects API Gateway from common web attacks (OWASP Top 10)
################################################################################

resource "aws_wafv2_web_acl" "main" {
  count = var.create_waf ? 1 : 0

  name        = "${local.resource_prefix}-waf"
  description = "WAF for ${local.resource_prefix} API Gateway"
  scope       = var.waf_scope # "REGIONAL" for API Gateway, "CLOUDFRONT" for CloudFront

  default_action {
    allow {}
  }

  #----------------------------------------------------------------------------
  # AWS Managed Rule - Common Rule Set (OWASP Core)
  #----------------------------------------------------------------------------
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
          for_each = var.waf_common_rules_excluded
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

  #----------------------------------------------------------------------------
  # AWS Managed Rule - Known Bad Inputs
  #----------------------------------------------------------------------------
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

  #----------------------------------------------------------------------------
  # AWS Managed Rule - SQL Injection Protection
  #----------------------------------------------------------------------------
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

  #----------------------------------------------------------------------------
  # AWS Managed Rule - Linux OS Protection
  #----------------------------------------------------------------------------
  rule {
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

  #----------------------------------------------------------------------------
  # Rate Limiting Rule - DDoS Protection
  #----------------------------------------------------------------------------
  rule {
    name     = "RateLimitRule"
    priority = 5

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # IP Reputation List - Block Known Bad IPs
  #----------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # Anonymous IP List - Block VPNs, Tor, Proxies (Optional)
  #----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.waf_block_anonymous_ips ? [1] : []
    content {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 7

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAnonymousIpList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-anonymous-ip"
        sampled_requests_enabled   = true
      }
    }
  }

  #----------------------------------------------------------------------------
  # Geo Restriction (Optional) - Allow only specific countries
  #----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = length(var.waf_allowed_countries) > 0 ? [1] : []
    content {
      name     = "GeoRestriction"
      priority = 8

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.waf_allowed_countries
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.resource_prefix}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  #----------------------------------------------------------------------------
  # IP Allowlist (Optional) - Only allow specific IPs
  #----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.waf_ip_allowlist_enabled ? [1] : []
    content {
      name     = "IPAllowlist"
      priority = 0 # Highest priority

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

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-waf"
  })
}

################################################################################
# WAF IP Allowlist (Optional)
################################################################################

resource "aws_wafv2_ip_set" "allowlist" {
  count = var.waf_ip_allowlist_enabled ? 1 : 0

  name               = "${local.resource_prefix}-ip-allowlist"
  description        = "Allowed IP addresses for ${local.resource_prefix}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.waf_ip_allowlist

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-ip-allowlist"
  })
}

################################################################################
# WAF Logging
################################################################################

resource "aws_cloudwatch_log_group" "waf" {
  count = var.create_waf ? 1 : 0

  # WAF logging requires log group name to start with aws-waf-logs-
  name              = "aws-waf-logs-${local.resource_prefix}"
  retention_in_days = var.waf_logs_retention_days
  kms_key_id        = aws_kms_key.waf[0].arn

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-waf-logs"
  })
}

resource "aws_kms_key" "waf" {
  count = var.create_waf ? 1 : 0

  description             = "KMS key for WAF logs encryption"
  deletion_window_in_days = 7
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
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.resource_prefix}"
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
  count = var.create_waf ? 1 : 0

  name          = "alias/${local.resource_prefix}-waf"
  target_key_id = aws_kms_key.waf[0].key_id
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.create_waf ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.main[0].arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }
}
