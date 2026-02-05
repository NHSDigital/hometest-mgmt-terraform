# HomeTest Service Application Infrastructure

This directory contains Terraform/Terragrunt configuration for deploying the HomeTest Service application infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CloudFront                                      │
│                         (SPA Distribution)                                   │
│                    ┌──────────────────────────────┐                         │
│                    │  Security Headers Policy      │                         │
│                    │  - CSP, X-Frame-Options       │                         │
│                    │  - HSTS, XSS Protection       │                         │
│                    └──────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌───────────────────┐           ┌───────────────────┐
        │   S3 Bucket       │           │   API Gateway     │
        │  (SPA Assets)     │           │   (REST API)      │
        │  - OAC Access     │           │  - X-Ray Tracing  │
        │  - Versioning     │           │  - WAF Integration│
        │  - Encryption     │           │  - Access Logging │
        └───────────────────┘           └───────────────────┘
                                                │
                    ┌───────────────────────────┼───────────────────────────┐
                    ▼                           ▼                           ▼
        ┌───────────────────┐       ┌───────────────────┐       ┌───────────────────┐
        │ Lambda Function   │       │ Lambda Function   │       │ Lambda Function   │
        │ eligibility-test  │       │ order-router      │       │ hello-world       │
        │ - X-Ray Tracing   │       │ - X-Ray Tracing   │       │ - X-Ray Tracing   │
        │ - KMS Encryption  │       │ - KMS Encryption  │       │ - KMS Encryption  │
        └───────────────────┘       └───────────────────┘       └───────────────────┘
```

## Security Features

### Lambda Functions
- ✅ X-Ray tracing enabled for distributed tracing
- ✅ KMS encryption for environment variables
- ✅ CloudWatch logs with encryption
- ✅ Least privilege IAM execution role
- ✅ VPC support for private resource access
- ✅ Dead letter queue support

### API Gateway
- ✅ CloudWatch access logging with structured JSON
- ✅ X-Ray tracing enabled
- ✅ WAF Web ACL integration
- ✅ Throttling configuration
- ✅ TLS 1.2 minimum for custom domains
- ✅ Regional endpoint with optional custom domain

### CloudFront SPA
- ✅ Origin Access Control (OAC) for S3
- ✅ Security headers (CSP, HSTS, X-Frame-Options, etc.)
- ✅ TLS 1.2 minimum protocol version
- ✅ HTTP/2 and HTTP/3 support
- ✅ SPA routing with CloudFront Functions
- ✅ Geo-restriction support
- ✅ WAF integration

### Developer Deployment Role
- ✅ MFA requirement
- ✅ IP-based restrictions (optional)
- ✅ External ID support (confused deputy protection)
- ✅ Explicit deny for dangerous actions
- ✅ Scoped to specific resources

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.5.0
3. Terragrunt >= 0.50.0
4. AWS CLI configured

## Deployment

### Infrastructure Deployment (via Terragrunt)

```bash
# Navigate to the environment directory
cd infrastructure/environments/poc/dev/hometest-app

# Initialize and plan
terragrunt init
terragrunt plan

# Apply the infrastructure
terragrunt apply
```

### Lambda Deployment (for Developers)

1. Configure AWS CLI with the developer deployment role:

```bash
# Add to ~/.aws/config
[profile nhs-hometest-dev-deploy]
role_arn = arn:aws:iam::ACCOUNT_ID:role/nhs-hometest-dev-developer-deploy
source_profile = default
mfa_serial = arn:aws:iam::YOUR_ACCOUNT_ID:mfa/YOUR_USERNAME
```

2. Build and deploy Lambda:

```bash
# Build Lambda
cd hometest-service/lambdas
npm run build

# Upload to S3
aws s3 cp dist/eligibility-test-info-lambda.zip \
  s3://nhs-hometest-dev-artifacts-ACCOUNT_ID/lambdas/ \
  --profile nhs-hometest-dev-deploy

# Update Lambda function
aws lambda update-function-code \
  --function-name nhs-hometest-dev-eligibility-test-info \
  --s3-bucket nhs-hometest-dev-artifacts-ACCOUNT_ID \
  --s3-key lambdas/eligibility-test-info-lambda.zip \
  --profile nhs-hometest-dev-deploy
```

### SPA Deployment (for Developers)

```bash
# Build SPA
cd hometest-service/ui
npm run build

# Deploy to S3
aws s3 sync out/ s3://nhs-hometest-dev-spa-ACCOUNT_ID \
  --delete \
  --profile nhs-hometest-dev-deploy

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*" \
  --profile nhs-hometest-dev-deploy
```

## Modules

| Module | Description |
|--------|-------------|
| `lambda` | Lambda function with security best practices |
| `lambda-iam` | Lambda execution IAM role with least privilege |
| `api-gateway` | REST API Gateway with logging and security |
| `cloudfront-spa` | CloudFront distribution for SPA with S3 origin |
| `deployment-artifacts` | S3 bucket for Lambda deployment packages |
| `developer-iam` | IAM role for developers to deploy applications |

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name prefix | `nhs-hometest` |
| `environment` | Environment name | Required |
| `lambda_runtime` | Lambda runtime | `nodejs20.x` |
| `lambda_timeout` | Lambda timeout (seconds) | `30` |
| `lambda_memory_size` | Lambda memory (MB) | `256` |
| `log_retention_days` | CloudWatch log retention | `30` |
| `developer_account_arns` | Developer IAM ARNs | Required |
| `developer_require_mfa` | Require MFA | `true` |

### Custom Domains

To use custom domains, set the following variables:

```hcl
# API Gateway custom domain
api_custom_domain_name  = "api.example.com"
api_acm_certificate_arn = "arn:aws:acm:eu-west-2:ACCOUNT:certificate/XXX"

# CloudFront custom domain (certificate must be in us-east-1)
spa_custom_domain_names = ["app.example.com"]
spa_acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/XXX"
route53_zone_id         = "Z1234567890"
```

## Outputs

After deployment, you'll have access to:

- `api_gateway_invoke_url` - API Gateway endpoint URL
- `cloudfront_url` - CloudFront distribution URL
- `developer_role_arn` - Developer deployment role ARN
- `deploy_lambda_command` - Commands to deploy Lambda
- `deploy_spa_command` - Commands to deploy SPA

## Troubleshooting

### Lambda deployment fails
- Ensure you have assumed the developer role with MFA
- Check S3 bucket permissions
- Verify Lambda function name matches

### CloudFront returns 403
- Check S3 bucket policy allows CloudFront OAC
- Verify index.html exists in S3
- Check CloudFront distribution is deployed

### API Gateway returns 500
- Check Lambda execution role permissions
- Review CloudWatch logs for Lambda errors
- Ensure environment variables are set correctly
