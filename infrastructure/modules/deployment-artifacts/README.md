# Deployment Artifacts Module

A Terraform module that creates an S3 bucket for storing Lambda deployment packages with security best practices.

## Overview

This module provisions a secure S3 bucket for Lambda ZIP archives and other deployment artifacts, implementing:

- All public access blocked
- Versioning enabled
- Server-side encryption (KMS or AES-256)
- Lifecycle rules for old version cleanup
- HTTPS-only access enforcement
- Lambda service principal access

## Usage

### Basic Usage

```hcl
module "deployment_artifacts" {
  source = "../modules/deployment-artifacts"

  project_name   = "hometest"
  environment    = "dev"
  aws_account_id = "123456789012"
}
```

### With KMS Encryption and Logging

```hcl
module "deployment_artifacts" {
  source = "../modules/deployment-artifacts"

  project_name   = "hometest"
  environment    = "dev"
  aws_account_id = "123456789012"

  kms_key_arn               = aws_kms_key.main.arn
  artifact_retention_days   = 90
  enable_intelligent_tiering = true
  logging_bucket_id         = aws_s3_bucket.logs.id

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
| `aws_account_id` | AWS account ID | `string` | - | Yes |
| `kms_key_arn` | ARN of KMS key for encryption | `string` | `null` | No |
| `artifact_retention_days` | Days to retain old artifact versions | `number` | `30` | No |
| `enable_intelligent_tiering` | Enable intelligent tiering for cost optimization | `bool` | `false` | No |
| `logging_bucket_id` | S3 bucket ID for access logging | `string` | `null` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | ID of the S3 bucket |
| `bucket_arn` | ARN of the S3 bucket |
| `bucket_name` | Name of the S3 bucket |

## Bucket Naming

The bucket is named using the pattern:

```bash
{project_name}-{environment}-artifacts-{aws_account_id}
```

Example: `hometest-dev-artifacts-123456789012`

## Security Features

### Public Access Block

All public access is blocked:

- `block_public_acls = true`
- `block_public_policy = true`
- `ignore_public_acls = true`
- `restrict_public_buckets = true`

### Encryption

- **With KMS**: Uses `aws:kms` with bucket key enabled
- **Without KMS**: Uses `AES256` (SSE-S3)

### Bucket Policy

The bucket policy:

1. **Denies non-HTTPS requests** — All requests must use TLS
2. **Allows Lambda service** — `lambda.amazonaws.com` can read objects with source account condition

### Lifecycle Rules

| Rule | Description |
|------|-------------|
| Old version cleanup | Expires non-current versions after `artifact_retention_days` |
| Incomplete uploads | Aborts multipart uploads after 7 days |
| Intelligent tiering | Transitions to STANDARD_IA after 30 days (optional) |

## Directory Structure

Recommended artifact organization:

```bash
{bucket}/
├── lambdas/
│   ├── hello-world/
│   │   └── v1.0.0.zip
│   ├── eligibility-test-info/
│   │   └── v1.0.0.zip
│   └── order-router/
│       └── v1.0.0.zip
└── spa/
    └── ui-v1.0.0.zip
```

## Related Modules

- [lambda](../lambda/) — Lambda function deployment using artifacts from this bucket
- [cloudfront-spa](../cloudfront-spa/) — SPA deployment
