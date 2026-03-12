# API Gateway Module

Terraform module for creating AWS API Gateway REST API with security best practices.

## Features

- **CloudWatch Logging**: Structured JSON access logs
- **X-Ray Tracing**: Distributed tracing enabled by default
- **WAF Integration**: Optional WAF Web ACL association
- **Throttling**: Configurable rate and burst limits
- **Custom Domains**: Support for custom domains with TLS 1.2
- **Caching**: Optional response caching

## Usage

```hcl
module "api" {
  source = "../../modules/api-gateway"

  project_name = "my-app"
  environment  = "prod"

  stage_name    = "v1"
  endpoint_type = "REGIONAL"

  # Logging
  log_retention_days   = 30
  xray_tracing_enabled = true

  # Throttling
  throttling_burst_limit = 5000
  throttling_rate_limit  = 10000

  # Security
  waf_web_acl_arn = module.waf.web_acl_arn

  # Custom domain
  custom_domain_name  = "api.example.com"
  acm_certificate_arn = "arn:aws:acm:eu-west-2:123456789012:certificate/xxx"

  tags = {
    Environment = "prod"
  }
}
```

## Log Format

Access logs are structured as JSON:

```json
{
  "requestId": "...",
  "sourceIp": "...",
  "requestTime": "...",
  "httpMethod": "GET",
  "resourcePath": "/test-order/info",
  "status": 200,
  "responseLength": 1234,
  "userAgent": "..."
}
```

## Security Best Practices

1. **TLS 1.2**: Minimum protocol version for custom domains
2. **Access Logging**: All requests logged to CloudWatch
3. **X-Ray**: Distributed tracing for debugging
4. **WAF**: Web Application Firewall integration
5. **Throttling**: Rate limiting to prevent abuse
