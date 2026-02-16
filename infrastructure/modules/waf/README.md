# WAF Module

A Terraform module that creates an AWS WAFv2 Web ACL with managed rules for protecting API Gateway and CloudFront distributions.

## Overview

This module provisions a WAFv2 Web ACL with:

- AWS Managed Rule Sets (Common, SQLi, Known Bad Inputs, IP Reputation, Anonymous IP)
- Rate limiting per IP address
- Geo-blocking support
- IP allow list support
- CloudWatch logging with field redaction

## Usage

### Regional WAF for API Gateway

```hcl
module "waf_api" {
  source = "../modules/waf"

  project_name = "hometest"
  environment  = "dev"
  scope        = "REGIONAL"

  enable_rate_limiting  = true
  rate_limit_threshold  = 2000  # requests per 5 minutes per IP

  tags = {
    Project = "hometest"
  }
}

# Associate with API Gateway
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = module.waf_api.web_acl_arn
}
```

### Global WAF for CloudFront

```hcl
module "waf_cloudfront" {
  source = "../modules/waf"

  project_name = "hometest"
  environment  = "dev"
  scope        = "CLOUDFRONT"  # Must be deployed in us-east-1

  blocked_countries = ["RU", "CN", "KP"]

  tags = {
    Project = "hometest"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | Yes |
| `environment` | Environment name | `string` | - | Yes |
| `scope` | WAF scope (`REGIONAL` or `CLOUDFRONT`) | `string` | `"REGIONAL"` | No |
| `common_ruleset_excluded_rules` | Rules to exclude from Common Rule Set | `list(string)` | `[]` | No |
| `enable_ip_reputation` | Enable AWS IP Reputation rule set | `bool` | `true` | No |
| `enable_anonymous_ip_list` | Enable AWS Anonymous IP List rule set | `bool` | `false` | No |
| `enable_rate_limiting` | Enable rate limiting rule | `bool` | `true` | No |
| `rate_limit_threshold` | Requests per 5-minute period per IP | `number` | `2000` | No |
| `blocked_countries` | List of country codes to block | `list(string)` | `[]` | No |
| `ip_allow_list_arn` | ARN of IP set for allow list | `string` | `null` | No |
| `enable_logging` | Enable WAF logging to CloudWatch | `bool` | `true` | No |
| `log_retention_days` | CloudWatch log retention in days | `number` | `30` | No |
| `kms_key_arn` | KMS key ARN for log encryption | `string` | `null` | No |
| `redacted_fields` | Fields to redact from logs | `list(object)` | `[authorization, cookie]` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `web_acl_arn` | ARN of the WAF Web ACL |
| `web_acl_id` | ID of the WAF Web ACL |
| `web_acl_name` | Name of the WAF Web ACL |
| `log_group_arn` | ARN of the CloudWatch log group |

## Rules

The Web ACL includes the following rules in priority order:

| Priority | Rule | Description |
|----------|------|-------------|
| 1 | AWSManagedRulesCommonRuleSet | Core rules (XSS, path traversal, etc.) |
| 2 | AWSManagedRulesKnownBadInputsRuleSet | Known malicious patterns |
| 3 | AWSManagedRulesSQLiRuleSet | SQL injection protection |
| 4 | AWSManagedRulesAmazonIpReputationList | Block IPs with poor reputation |
| 5 | AWSManagedRulesAnonymousIpList | Block VPN/proxy IPs (optional) |
| 10 | RateLimit | Rate limiting per IP |
| 20 | GeoBlock | Block requests from specified countries |
| 30 | IPAllowList | Allow requests from specific IPs |

## Scope

| Scope | Use Case | Region |
|-------|----------|--------|
| `REGIONAL` | API Gateway, ALB, AppSync | Any region |
| `CLOUDFRONT` | CloudFront distributions | **us-east-1 only** |

## Logging

When `enable_logging = true`:

- Logs are written to CloudWatch Logs: `aws-waf-logs-{project_name}-{environment}`
- Sensitive headers are redacted by default: `authorization`, `cookie`
- Optional KMS encryption via `kms_key_arn`

### Custom Redaction

```hcl
module "waf" {
  source = "../modules/waf"

  # ... other variables ...

  redacted_fields = [
    { type = "single_header", name = "authorization" },
    { type = "single_header", name = "cookie" },
    { type = "single_header", name = "x-api-key" },
  ]
}
```

## Excluding Rules

To switch specific rules to COUNT mode (monitor without blocking):

```hcl
module "waf" {
  source = "../modules/waf"

  # ... other variables ...

  common_ruleset_excluded_rules = [
    "SizeRestrictions_BODY",
    "CrossSiteScripting_BODY"
  ]
}
```

## Security Notes

- **Default action**: ALLOW (rules explicitly block threats)
- **CloudWatch metrics**: Enabled for all rules
- **Sampled requests**: Enabled for debugging
- **Rate limiting**: Protects against DDoS and brute force attacks

## Related Modules

- [api-gateway](../api-gateway/) — API Gateway with WAF association
- [cloudfront-spa](../cloudfront-spa/) — CloudFront distribution with WAF
