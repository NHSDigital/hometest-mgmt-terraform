# HomeTest Infrastructure - Module Reference

This document provides detailed reference for all Terraform modules used in the HomeTest infrastructure.

## Table of Contents

- [Application Module](#application-module)
- [API Gateway Module](#api-gateway-module)
- [WAF Module](#waf-module)
- [DNS Certificate Module](#dns-certificate-module)
- [IAM Developer Role Module](#iam-developer-role-module)

---

## Application Module

**Path**: `infrastructure/src/application`

The Application module provisions Lambda functions with supporting resources for serverless application deployment.

### Features

- Lambda function with configurable runtime and handler
- S3 or local zip artifact deployment
- VPC integration (optional)
- X-Ray tracing
- CloudWatch logging with KMS encryption
- CloudWatch alarms for monitoring
- Artifacts S3 bucket for deployment packages

### Usage

```hcl
# infrastructure/environments/poc/dev/application/terragrunt.hcl
inputs = {
  lambda_name        = "api"
  lambda_description = "HomeTest API Lambda"
  lambda_handler     = "index.handler"
  lambda_runtime     = "nodejs20.x"
  lambda_timeout     = 30
  lambda_memory_size = 256

  # Deployment from S3
  lambda_s3_bucket = "nhs-hometest-poc-dev-lambda-artifacts"
  lambda_s3_key    = "api.zip"

  # VPC configuration
  enable_vpc             = true
  vpc_subnet_ids         = ["subnet-123", "subnet-456"]
  vpc_security_group_ids = ["sg-789"]

  # Environment variables
  environment_variables = {
    NODE_ENV    = "development"
    LOG_LEVEL   = "debug"
  }
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `lambda_name` | Name suffix for the Lambda function | `string` | `"api"` | No |
| `lambda_handler` | Lambda function handler | `string` | `"index.handler"` | No |
| `lambda_runtime` | Lambda function runtime | `string` | `"nodejs20.x"` | No |
| `lambda_timeout` | Timeout in seconds (1-900) | `number` | `30` | No |
| `lambda_memory_size` | Memory size in MB (128-10240) | `number` | `256` | No |
| `lambda_s3_bucket` | S3 bucket for deployment package | `string` | `""` | No |
| `lambda_s3_key` | S3 key for deployment package | `string` | `""` | No |
| `lambda_filename` | Local path to deployment package | `string` | `""` | No |
| `enable_vpc` | Deploy Lambda in VPC | `bool` | `false` | No |
| `vpc_subnet_ids` | List of VPC subnet IDs | `list(string)` | `[]` | No |
| `vpc_security_group_ids` | List of security group IDs | `list(string)` | `[]` | No |
| `environment_variables` | Environment variables map | `map(string)` | `{}` | No |
| `enable_xray_tracing` | Enable X-Ray tracing | `bool` | `true` | No |
| `create_artifacts_bucket` | Create S3 artifacts bucket | `bool` | `true` | No |
| `create_alarms` | Create CloudWatch alarms | `bool` | `true` | No |

### Outputs

| Name | Description |
|------|-------------|
| `lambda_function_name` | The name of the Lambda function |
| `lambda_function_arn` | The ARN of the Lambda function |
| `lambda_invoke_arn` | The invoke ARN (for API Gateway) |
| `lambda_execution_role_arn` | The ARN of the execution role |
| `artifacts_bucket_id` | The S3 bucket ID for artifacts |
| `log_group_name` | CloudWatch Log Group name |

---

## API Gateway Module

**Path**: `infrastructure/src/api-gateway`

The API Gateway module provisions a REST API with mTLS support, custom domain, and Lambda integration.

### Features

- Regional REST API with Lambda proxy integration
- Mutual TLS (mTLS) authentication with S3-based truststore
- Custom domain name with ACM certificate
- Access logging with CloudWatch
- X-Ray tracing integration
- Configurable throttling

### Usage

```hcl
# infrastructure/environments/poc/dev/api-gateway/terragrunt.hcl
inputs = {
  lambda_function_name = "nhs-hometest-poc-dev-api"
  lambda_invoke_arn    = "arn:aws:apigateway:eu-west-2:lambda:path/..."

  # mTLS (optional)
  enable_mtls        = true
  truststore_content = file("ca-bundle.pem")

  # Custom domain
  create_custom_domain = true
  domain_name          = "dev.hometest.service.nhs.uk"
  certificate_arn      = "arn:aws:acm:..."

  # Configuration
  stage_name             = "v1"
  throttling_rate_limit  = 2000
  throttling_burst_limit = 1000
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `lambda_function_name` | Lambda function name for integration | `string` | - | Yes |
| `lambda_invoke_arn` | Lambda invoke ARN | `string` | - | Yes |
| `enable_mtls` | Enable mTLS authentication | `bool` | `true` | No |
| `truststore_content` | PEM content for mTLS truststore | `string` | `""` | No |
| `create_custom_domain` | Create custom domain name | `bool` | `true` | No |
| `domain_name` | Custom domain name | `string` | `""` | No |
| `certificate_arn` | ACM certificate ARN | `string` | `""` | No |
| `stage_name` | API Gateway stage name | `string` | `"v1"` | No |
| `authorization_type` | Authorization type | `string` | `"NONE"` | No |
| `throttling_rate_limit` | Requests per second | `number` | `10000` | No |
| `throttling_burst_limit` | Burst limit | `number` | `5000` | No |
| `enable_xray_tracing` | Enable X-Ray tracing | `bool` | `true` | No |
| `log_retention_days` | Log retention period | `number` | `90` | No |

### Outputs

| Name | Description |
|------|-------------|
| `rest_api_id` | The ID of the REST API |
| `rest_api_execution_arn` | The execution ARN |
| `invoke_url` | The default invoke URL |
| `api_endpoint` | Custom domain endpoint URL |
| `stage_arn_for_waf` | Stage ARN for WAF association |
| `custom_domain_regional_domain_name` | Regional domain for Route53 alias |
| `custom_domain_regional_zone_id` | Regional zone ID for Route53 alias |

---

## WAF Module

**Path**: `infrastructure/src/waf`

The WAF module provisions a Web Application Firewall (WAF v2) Web ACL with managed rules and custom configurations.

### Features

- AWS Managed Rules (Common, Known Bad Inputs, SQLi, Linux)
- Rate limiting
- IP allowlist and blocklist
- Geographic restrictions
- CloudWatch logging with sensitive field redaction
- API Gateway association

### Usage

```hcl
# infrastructure/environments/poc/dev/waf/terragrunt.hcl
inputs = {
  api_gateway_stage_arn = "arn:aws:apigateway:..."

  # Rate limiting
  enable_rate_limiting = true
  rate_limit           = 2000

  # IP filtering (optional)
  enable_ip_allowlist  = false
  enable_ip_blocklist  = true
  blocked_ip_addresses = ["203.0.113.5/32"]

  # Geo restriction (optional)
  enable_geo_restriction = true
  allowed_countries      = ["GB", "IE"]

  # Logging
  log_all_requests   = false  # Only log blocked/counted
  log_retention_days = 90
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `api_gateway_stage_arn` | API Gateway stage ARN to protect | `string` | `""` | No |
| `common_rules_excluded` | Rules to exclude from Common Rule Set | `list(string)` | `[]` | No |
| `enable_linux_rules` | Enable Linux OS rules | `bool` | `true` | No |
| `enable_rate_limiting` | Enable rate limiting | `bool` | `true` | No |
| `rate_limit` | Requests per 5 minutes per IP | `number` | `2000` | No |
| `enable_ip_allowlist` | Enable IP allowlist | `bool` | `false` | No |
| `allowed_ip_addresses` | Allowed IPs (CIDR notation) | `list(string)` | `[]` | No |
| `enable_ip_blocklist` | Enable IP blocklist | `bool` | `false` | No |
| `blocked_ip_addresses` | Blocked IPs (CIDR notation) | `list(string)` | `[]` | No |
| `enable_geo_restriction` | Enable geo restriction | `bool` | `false` | No |
| `allowed_countries` | Allowed country codes | `list(string)` | `["GB"]` | No |
| `log_all_requests` | Log all requests (vs blocked only) | `bool` | `false` | No |
| `log_retention_days` | Log retention period | `number` | `90` | No |

### Outputs

| Name | Description |
|------|-------------|
| `web_acl_id` | The ID of the WAF Web ACL |
| `web_acl_arn` | The ARN of the WAF Web ACL |
| `web_acl_capacity` | Web ACL capacity units used |
| `log_group_name` | CloudWatch Log Group name |

---

## DNS Certificate Module

**Path**: `infrastructure/src/dns-certificate`

The DNS Certificate module provisions ACM certificates with DNS validation and Route53 records.

### Features

- ACM certificate with DNS validation
- Automatic Route53 validation records
- A record alias for API Gateway
- Route53 health checks (optional)
- Certificate transparency logging

### Usage

```hcl
# infrastructure/environments/poc/dev/dns-certificate/terragrunt.hcl
inputs = {
  base_domain_name        = "hometest.service.nhs.uk"
  additional_domain_names = []

  # API Gateway integration
  create_api_gateway_record        = true
  api_gateway_regional_domain_name = "d-abc123.execute-api.eu-west-2.amazonaws.com"
  api_gateway_regional_zone_id     = "ZJ5UAJN8Y3Z2Q"

  # Health check
  create_health_check = true
  health_check_path   = "/health"
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `base_domain_name` | Base domain name | `string` | `"hometest.service.nhs.uk"` | No |
| `additional_domain_names` | Additional SANs | `list(string)` | `[]` | No |
| `create_api_gateway_record` | Create A record for API Gateway | `bool` | `false` | No |
| `api_gateway_regional_domain_name` | API Gateway regional domain | `string` | `""` | No |
| `api_gateway_regional_zone_id` | API Gateway regional zone ID | `string` | `""` | No |
| `create_health_check` | Create Route53 health check | `bool` | `false` | No |
| `health_check_path` | Health check path | `string` | `"/health"` | No |

### Outputs

| Name | Description |
|------|-------------|
| `certificate_arn` | The ARN of the ACM certificate |
| `certificate_domain_name` | The certificate domain name |
| `environment_fqdn` | The FQDN for this environment |
| `api_endpoint_url` | The full API endpoint URL |
| `zone_id` | The Route53 zone ID |

---

## IAM Developer Role Module

**Path**: `infrastructure/src/iam-developer-role`

The IAM Developer Role module provisions a scoped IAM role for developers with environment-specific permissions.

### Features

- Environment-scoped permissions (Lambda, API Gateway, logs)
- Multiple trust relationships (SSO, AFT, GitHub OIDC, account)
- Read-only access to CloudTrail and CloudWatch
- Ready for AWS AFT integration
- Configurable session duration

### Usage

```hcl
# infrastructure/environments/poc/dev/iam-developer-role/terragrunt.hcl
inputs = {
  # Trust configuration
  enable_sso_trust         = true
  allowed_teams            = ["developers", "platform"]
  enable_aft_trust         = true
  aft_management_account_id = "123456789012"
  enable_github_oidc_trust = true
  github_repo              = "NHSDigital/hometest-mgmt-terraform"
  enable_account_trust     = false  # Disable in production

  # Session
  max_session_duration = 3600
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `enable_sso_trust` | Enable AWS SSO trust | `bool` | `false` | No |
| `allowed_teams` | Teams allowed to assume role | `list(string)` | `["developers"]` | No |
| `enable_aft_trust` | Enable AFT trust | `bool` | `true` | No |
| `aft_management_account_id` | AFT management account ID | `string` | `""` | No |
| `aft_external_id` | AFT external ID | `string` | `""` | No |
| `enable_github_oidc_trust` | Enable GitHub OIDC trust | `bool` | `false` | No |
| `github_repo` | GitHub repo for OIDC | `string` | `""` | No |
| `enable_account_trust` | Enable account root trust | `bool` | `false` | No |
| `max_session_duration` | Max session duration (seconds) | `number` | `3600` | No |

### Outputs

| Name | Description |
|------|-------------|
| `role_arn` | The ARN of the developer role |
| `role_name` | The name of the developer role |
| `aft_role_reference` | Role ARN for AFT configuration |
| `aft_config` | Full AFT integration config |
| `permission_scope` | Description of permission scope |

### Permission Scope

The developer role has the following permissions:

| Resource Type | Read | Write | Scope |
|---------------|------|-------|-------|
| Lambda | ✅ All | ✅ | Environment functions only |
| API Gateway | ✅ All | ✅ | Environment APIs only |
| CloudWatch Logs | ✅ | ❌ | Environment log groups only |
| CloudWatch Metrics | ✅ | ❌ | All |
| X-Ray | ✅ | ❌ | All |
| CloudTrail | ✅ | ❌ | All |
| S3 | ✅ | ✅ | Artifacts bucket only |
| KMS | ✅ | ✅ | Environment keys only |
| IAM | ✅ | ❌ | Environment roles/policies only |
