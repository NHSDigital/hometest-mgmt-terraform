# Developer IAM Module

Terraform module for creating IAM roles that allow developers to deploy Lambda functions and SPA from their accounts.

## Features

- **Cross-Account Access**: Developers can assume this role from their AWS accounts
- **MFA Requirement**: Optional MFA enforcement
- **IP Restrictions**: Optional source IP restrictions
- **External ID**: Optional confused deputy protection
- **Scoped Permissions**: Least privilege access for deployment tasks
- **Explicit Denies**: Prevents dangerous actions like IAM changes

## Usage

```hcl
module "developer_iam" {
  source = "../../modules/developer-iam"

  project_name   = "my-app"
  environment    = "dev"
  aws_account_id = "123456789012"
  aws_region     = "eu-west-2"

  # Allow specific developers to assume this role
  developer_account_arns = [
    "arn:aws:iam::987654321098:user/developer1",
    "arn:aws:iam::987654321098:user/developer2",
    "arn:aws:iam::987654321098:role/DeveloperRole"
  ]

  # Security requirements
  require_mfa = true
  allowed_ip_ranges = ["10.0.0.0/8", "192.168.1.0/24"]

  # Resource references
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  kms_key_arns = [aws_kms_key.main.arn]

  tags = {
    Purpose = "developer-deployment"
  }
}
```

## Permissions Granted

| Action | Scope |
|--------|-------|
| Lambda UpdateFunctionCode | Project Lambdas only |
| Lambda UpdateFunctionConfiguration | Project Lambdas only |
| Lambda InvokeFunction | Project Lambdas only |
| S3 GetObject/PutObject | SPA and artifacts buckets |
| CloudFront CreateInvalidation | Project distribution |
| CloudWatch Logs Read | Project log groups |

## Permissions Denied

The following actions are explicitly denied:
- IAM modifications
- Organization changes
- S3 bucket deletion
- Lambda function deletion
- CloudTrail modifications

## AWS CLI Configuration

Add to `~/.aws/config`:

```ini
[profile my-app-dev-deploy]
role_arn = arn:aws:iam::123456789012:role/my-app-dev-developer-deploy
source_profile = default
mfa_serial = arn:aws:iam::YOUR_ACCOUNT:mfa/YOUR_USERNAME
```

## Deployment Commands

```bash
# Upload Lambda
aws s3 cp lambda.zip s3://my-app-dev-artifacts-123456789012/lambdas/ \
  --profile my-app-dev-deploy

# Update Lambda
aws lambda update-function-code \
  --function-name my-app-dev-my-function \
  --s3-bucket my-app-dev-artifacts-123456789012 \
  --s3-key lambdas/my-function.zip \
  --profile my-app-dev-deploy

# Deploy SPA
aws s3 sync ./dist s3://my-app-dev-spa-123456789012 --delete \
  --profile my-app-dev-deploy

# Invalidate Cache
aws cloudfront create-invalidation \
  --distribution-id E1234567890 \
  --paths "/*" \
  --profile my-app-dev-deploy
```
