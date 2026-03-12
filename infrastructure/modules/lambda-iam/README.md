# Lambda IAM Module

A Terraform module that creates a least-privilege IAM execution role for AWS Lambda functions with configurable access policies.

## Overview

This module creates an IAM role and associated policies for Lambda function execution, following AWS security best practices:

- Scoped CloudWatch Logs permissions
- Optional VPC access (for Lambda in VPC)
- Optional X-Ray tracing
- Conditional access to Secrets Manager, SSM Parameter Store, KMS, S3, DynamoDB, and SQS
- Support for custom policies and AWS managed policy attachments

## Usage

### Basic Usage

```hcl
module "lambda_iam" {
  source = "../modules/lambda-iam"

  project_name   = "hometest"
  environment    = "dev"
  aws_account_id = "123456789012"
  aws_region     = "eu-west-2"
}
```

### With VPC and Secrets Access

```hcl
module "lambda_iam" {
  source = "../modules/lambda-iam"

  project_name   = "hometest"
  environment    = "dev"
  aws_account_id = "123456789012"
  aws_region     = "eu-west-2"

  # VPC access for Lambdas deployed in VPC
  enable_vpc_access = true
  vpc_id            = "vpc-abc123"

  # Secrets Manager access
  secrets_arns = [
    "arn:aws:secretsmanager:eu-west-2:123456789012:secret:my-secret-*"
  ]

  # KMS decryption
  kms_key_arns = [
    "arn:aws:kms:eu-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]
}
```

### With SQS Trigger

```hcl
module "lambda_iam" {
  source = "../modules/lambda-iam"

  project_name   = "hometest"
  environment    = "dev"
  aws_account_id = "123456789012"
  aws_region     = "eu-west-2"

  enable_sqs_access = true
  sqs_queue_arns    = [aws_sqs_queue.orders.arn]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | Yes |
| `environment` | Environment name (dev, staging, prod) | `string` | - | Yes |
| `aws_account_id` | AWS account ID | `string` | - | Yes |
| `aws_region` | AWS region | `string` | - | Yes |
| `max_session_duration` | Maximum session duration in seconds | `number` | `3600` | No |
| `restrict_to_account` | Restrict role assumption to specific account | `bool` | `true` | No |
| `enable_xray` | Enable X-Ray tracing permissions | `bool` | `true` | No |
| `enable_vpc_access` | Enable VPC access permissions | `bool` | `false` | No |
| `vpc_id` | VPC ID for VPC access condition | `string` | `null` | No |
| `secrets_arns` | List of Secrets Manager secret ARNs | `list(string)` | `[]` | No |
| `ssm_parameter_arns` | List of SSM parameter ARNs | `list(string)` | `[]` | No |
| `kms_key_arns` | List of KMS key ARNs for decryption | `list(string)` | `[]` | No |
| `s3_bucket_arns` | List of S3 bucket ARNs | `list(string)` | `[]` | No |
| `dynamodb_table_arns` | List of DynamoDB table ARNs | `list(string)` | `[]` | No |
| `sqs_queue_arns` | List of SQS queue ARNs | `list(string)` | `[]` | No |
| `enable_sqs_access` | Enable SQS access policy | `bool` | `false` | No |
| `custom_policies` | Map of custom policy names to policy JSON | `map(string)` | `{}` | No |
| `managed_policy_arns` | List of managed policy ARNs to attach | `list(string)` | `[]` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | ARN of the Lambda execution role |
| `role_name` | Name of the Lambda execution role |
| `role_id` | ID of the Lambda execution role |

## Policies Created

| Policy | Condition | Permissions |
|--------|-----------|-------------|
| CloudWatch Logs | Always | Create log groups, streams, write events |
| X-Ray | `enable_xray = true` | Put trace segments, telemetry |
| VPC Access | `enable_vpc_access = true` | Create/delete/describe ENIs |
| Secrets Manager | `secrets_arns` non-empty | GetSecretValue, DescribeSecret |
| SSM Parameters | `ssm_parameter_arns` non-empty | GetParameter, GetParameters |
| KMS | `kms_key_arns` non-empty | Decrypt, GenerateDataKey |
| S3 | `s3_bucket_arns` non-empty | GetObject, PutObject, ListBucket |
| DynamoDB | `dynamodb_table_arns` non-empty | Full table access |
| SQS | `enable_sqs_access = true` | ReceiveMessage, DeleteMessage, GetQueueAttributes |

## Security Features

- **Scoped resources**: All policies use explicit resource ARNs where possible
- **Account restriction**: Optional source account condition on assume role
- **Tag-based naming**: Role name includes project and environment for traceability
- **No wildcards**: Avoids `*` resources except where required (VPC ENIs, X-Ray)

## Related Modules

- [lambda](../lambda/) — Lambda function deployment
- [sqs](../sqs/) — SQS queues for Lambda triggers
