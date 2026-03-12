# CloudFront SPA Module

Terraform module for deploying a Single Page Application (SPA) on CloudFront with S3 origin.

## Features

- **S3 Bucket**: Private bucket with versioning and encryption
- **Origin Access Control**: Secure OAC for S3 access
- **Security Headers**: CSP, HSTS, X-Frame-Options, etc.
- **SPA Routing**: CloudFront Function for client-side routing
- **API Integration**: Optional API Gateway origin for `/api/*` paths
- **Custom Domains**: Support for custom domains with ACM certificates
- **WAF Integration**: Optional WAF Web ACL association
- **Geo Restrictions**: Optional geographic access control

## Usage

```hcl
module "spa" {
  source = "../../modules/cloudfront-spa"

  project_name   = "my-app"
  environment    = "prod"
  aws_account_id = "123456789012"

  # Custom domain (certificate must be in us-east-1)
  custom_domain_names = ["app.example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
  route53_zone_id     = "Z1234567890"

  # API Gateway integration
  api_gateway_domain_name = "xyz.execute-api.eu-west-2.amazonaws.com"
  api_gateway_origin_path = "/v1"

  # Security
  waf_web_acl_arn = module.waf.web_acl_arn

  tags = {
    Environment = "prod"
  }
}
```

## Security Features

1. **S3 Security**
   - Public access blocked
   - Server-side encryption (AES256 or KMS)
   - Versioning enabled
   - HTTPS-only bucket policy

2. **CloudFront Security**
   - Origin Access Control (OAC)
   - TLS 1.2 minimum
   - HTTP/2 and HTTP/3
   - Security headers policy
   - Optional WAF integration

3. **Headers Applied**
   - Content-Security-Policy
   - Strict-Transport-Security
   - X-Content-Type-Options
   - X-Frame-Options
   - Referrer-Policy
   - Permissions-Policy
