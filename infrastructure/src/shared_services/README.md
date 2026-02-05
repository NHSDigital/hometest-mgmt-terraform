# Shared Services

This Terraform source contains resources shared across all HomeTest environments:

## Resources

| Resource | Description | Scope |
|----------|-------------|-------|
| **KMS Key** | Encryption key for Lambda env vars, S3, CloudWatch | All environments |
| **WAF Regional** | Web ACL for API Gateway protection | All API Gateways |
| **WAF CloudFront** | Web ACL for CloudFront (us-east-1) | All SPAs |
| **ACM Regional** | Wildcard certificate for API Gateway | All API custom domains |
| **ACM CloudFront** | Wildcard certificate (us-east-1) | All SPA custom domains |
| **S3 Bucket** | Deployment artifacts bucket | Lambda packages |
| **Developer IAM** | Cross-account deployment role | CI/CD |

## Usage

Deploy shared services first, then reference outputs in environment deployments:

```bash
cd infrastructure/environments/poc/core/shared_services
terragrunt apply
```

## Outputs for App Deployments

The `shared_config` output provides all values needed by hometest-app:

```hcl
dependency "shared" {
  config_path = "../../core/shared_services"
}

inputs = {
  kms_key_arn             = dependency.shared.outputs.kms_key_arn
  waf_web_acl_arn         = dependency.shared.outputs.waf_regional_arn
  waf_cloudfront_acl_arn  = dependency.shared.outputs.waf_cloudfront_arn
  api_acm_certificate_arn = dependency.shared.outputs.acm_regional_certificate_arn
  spa_acm_certificate_arn = dependency.shared.outputs.acm_cloudfront_certificate_arn
  deployment_bucket_id    = dependency.shared.outputs.deployment_artifacts_bucket_id
}
```
