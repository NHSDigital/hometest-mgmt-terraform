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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_api_gateway"></a> [api\_gateway](#module\_api\_gateway) | ../../../modules/api-gateway | n/a |
| <a name="module_cloudfront_spa"></a> [cloudfront\_spa](#module\_cloudfront\_spa) | ../../../modules/cloudfront-spa | n/a |
| <a name="module_deployment_artifacts"></a> [deployment\_artifacts](#module\_deployment\_artifacts) | ../../../modules/deployment-artifacts | n/a |
| <a name="module_developer_iam"></a> [developer\_iam](#module\_developer\_iam) | ../../../modules/developer-iam | n/a |
| <a name="module_eligibility_test_info_lambda"></a> [eligibility\_test\_info\_lambda](#module\_eligibility\_test\_info\_lambda) | ../../../modules/lambda | n/a |
| <a name="module_hello_world_lambda"></a> [hello\_world\_lambda](#module\_hello\_world\_lambda) | ../../../modules/lambda | n/a |
| <a name="module_lambda_iam"></a> [lambda\_iam](#module\_lambda\_iam) | ../../../modules/lambda-iam | n/a |
| <a name="module_order_router_lambda"></a> [order\_router\_lambda](#module\_order\_router\_lambda) | ../../../modules/lambda | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_integration.eligibility_test_info](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.hello_world](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.order_router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_method.eligibility_test_info](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.hello_world](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.order_router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_resource.hello_world](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.test_order](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.test_order_info](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.test_order_order](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_lambda_permission.eligibility_test_info](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.hello_world](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.order_router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_acm_certificate_arn"></a> [api\_acm\_certificate\_arn](#input\_api\_acm\_certificate\_arn) | ACM certificate ARN for API custom domain | `string` | `null` | no |
| <a name="input_api_custom_domain_name"></a> [api\_custom\_domain\_name](#input\_api\_custom\_domain\_name) | Custom domain name for API Gateway | `string` | `null` | no |
| <a name="input_api_endpoint_type"></a> [api\_endpoint\_type](#input\_api\_endpoint\_type) | API Gateway endpoint type | `string` | `"REGIONAL"` | no |
| <a name="input_api_stage_name"></a> [api\_stage\_name](#input\_api\_stage\_name) | API Gateway stage name | `string` | `"v1"` | no |
| <a name="input_api_throttling_burst_limit"></a> [api\_throttling\_burst\_limit](#input\_api\_throttling\_burst\_limit) | API Gateway throttling burst limit | `number` | `5000` | no |
| <a name="input_api_throttling_rate_limit"></a> [api\_throttling\_rate\_limit](#input\_api\_throttling\_rate\_limit) | API Gateway throttling rate limit | `number` | `10000` | no |
| <a name="input_artifact_retention_days"></a> [artifact\_retention\_days](#input\_artifact\_retention\_days) | Days to retain old deployment artifacts | `number` | `30` | no |
| <a name="input_cloudfront_logging_bucket_domain_name"></a> [cloudfront\_logging\_bucket\_domain\_name](#input\_cloudfront\_logging\_bucket\_domain\_name) | S3 bucket domain name for CloudFront access logs | `string` | `null` | no |
| <a name="input_cloudfront_price_class"></a> [cloudfront\_price\_class](#input\_cloudfront\_price\_class) | CloudFront price class | `string` | `"PriceClass_100"` | no |
| <a name="input_content_security_policy"></a> [content\_security\_policy](#input\_content\_security\_policy) | Content Security Policy header | `string` | `"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"` | no |
| <a name="input_developer_account_arns"></a> [developer\_account\_arns](#input\_developer\_account\_arns) | IAM ARNs of developers who can assume the deployment role | `list(string)` | `[]` | no |
| <a name="input_developer_allowed_ip_ranges"></a> [developer\_allowed\_ip\_ranges](#input\_developer\_allowed\_ip\_ranges) | IP ranges allowed for developer role assumption | `list(string)` | `[]` | no |
| <a name="input_developer_external_id"></a> [developer\_external\_id](#input\_developer\_external\_id) | External ID for developer role assumption | `string` | `null` | no |
| <a name="input_developer_require_external_id"></a> [developer\_require\_external\_id](#input\_developer\_require\_external\_id) | Require external ID for developer role assumption | `bool` | `false` | no |
| <a name="input_developer_require_mfa"></a> [developer\_require\_mfa](#input\_developer\_require\_mfa) | Require MFA for developer role assumption | `bool` | `true` | no |
| <a name="input_eligibility_test_info_env_vars"></a> [eligibility\_test\_info\_env\_vars](#input\_eligibility\_test\_info\_env\_vars) | Additional environment variables for eligibility-test-info Lambda | `map(string)` | `{}` | no |
| <a name="input_eligibility_test_info_hash"></a> [eligibility\_test\_info\_hash](#input\_eligibility\_test\_info\_hash) | Source code hash for eligibility-test-info Lambda | `string` | `null` | no |
| <a name="input_enable_cloudfront_logging"></a> [enable\_cloudfront\_logging](#input\_enable\_cloudfront\_logging) | Enable CloudFront access logging | `bool` | `false` | no |
| <a name="input_enable_vpc_access"></a> [enable\_vpc\_access](#input\_enable\_vpc\_access) | Enable VPC access for Lambda functions | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod) | `string` | n/a | yes |
| <a name="input_geo_restriction_locations"></a> [geo\_restriction\_locations](#input\_geo\_restriction\_locations) | List of country codes for geo restriction | `list(string)` | `[]` | no |
| <a name="input_geo_restriction_type"></a> [geo\_restriction\_type](#input\_geo\_restriction\_type) | Geo restriction type (whitelist, blacklist, none) | `string` | `"none"` | no |
| <a name="input_hello_world_hash"></a> [hello\_world\_hash](#input\_hello\_world\_hash) | Source code hash for hello-world Lambda | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of KMS key for encryption | `string` | `null` | no |
| <a name="input_lambda_dynamodb_table_arns"></a> [lambda\_dynamodb\_table\_arns](#input\_lambda\_dynamodb\_table\_arns) | DynamoDB table ARNs for Lambda access | `list(string)` | `[]` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda memory size in MB | `number` | `256` | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | Lambda runtime | `string` | `"nodejs20.x"` | no |
| <a name="input_lambda_s3_bucket_arns"></a> [lambda\_s3\_bucket\_arns](#input\_lambda\_s3\_bucket\_arns) | S3 bucket ARNs for Lambda access | `list(string)` | `[]` | no |
| <a name="input_lambda_secrets_arns"></a> [lambda\_secrets\_arns](#input\_lambda\_secrets\_arns) | Secrets Manager ARNs for Lambda access | `list(string)` | `[]` | no |
| <a name="input_lambda_security_group_ids"></a> [lambda\_security\_group\_ids](#input\_lambda\_security\_group\_ids) | Security group IDs for Lambda VPC configuration | `list(string)` | `null` | no |
| <a name="input_lambda_sqs_queue_arns"></a> [lambda\_sqs\_queue\_arns](#input\_lambda\_sqs\_queue\_arns) | SQS queue ARNs for Lambda access | `list(string)` | `[]` | no |
| <a name="input_lambda_ssm_parameter_arns"></a> [lambda\_ssm\_parameter\_arns](#input\_lambda\_ssm\_parameter\_arns) | SSM parameter ARNs for Lambda access | `list(string)` | `[]` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda timeout in seconds | `number` | `30` | no |
| <a name="input_lambda_vpc_subnet_ids"></a> [lambda\_vpc\_subnet\_ids](#input\_lambda\_vpc\_subnet\_ids) | Subnet IDs for Lambda VPC configuration | `list(string)` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days | `number` | `30` | no |
| <a name="input_order_router_env_vars"></a> [order\_router\_env\_vars](#input\_order\_router\_env\_vars) | Additional environment variables for order-router Lambda | `map(string)` | `{}` | no |
| <a name="input_order_router_hash"></a> [order\_router\_hash](#input\_order\_router\_hash) | Source code hash for order-router Lambda | `string` | `null` | no |
| <a name="input_permissions_policy"></a> [permissions\_policy](#input\_permissions\_policy) | Permissions Policy header | `string` | `"accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID | `string` | `null` | no |
| <a name="input_spa_acm_certificate_arn"></a> [spa\_acm\_certificate\_arn](#input\_spa\_acm\_certificate\_arn) | ACM certificate ARN for CloudFront custom domains (must be in us-east-1) | `string` | `null` | no |
| <a name="input_spa_custom_domain_names"></a> [spa\_custom\_domain\_names](#input\_spa\_custom\_domain\_names) | Custom domain names for CloudFront SPA | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for Lambda functions | `string` | `null` | no |
| <a name="input_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#input\_waf\_web\_acl\_arn) | WAF Web ACL ARN | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | ID of the REST API |
| <a name="output_api_gateway_invoke_url"></a> [api\_gateway\_invoke\_url](#output\_api\_gateway\_invoke\_url) | URL to invoke the API |
| <a name="output_api_gateway_stage_name"></a> [api\_gateway\_stage\_name](#output\_api\_gateway\_stage\_name) | API Gateway stage name |
| <a name="output_artifacts_bucket_arn"></a> [artifacts\_bucket\_arn](#output\_artifacts\_bucket\_arn) | S3 bucket ARN for deployment artifacts |
| <a name="output_artifacts_bucket_id"></a> [artifacts\_bucket\_id](#output\_artifacts\_bucket\_id) | S3 bucket ID for deployment artifacts |
| <a name="output_cloudfront_distribution_arn"></a> [cloudfront\_distribution\_arn](#output\_cloudfront\_distribution\_arn) | CloudFront distribution ARN |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | CloudFront distribution ID |
| <a name="output_cloudfront_domain_name"></a> [cloudfront\_domain\_name](#output\_cloudfront\_domain\_name) | CloudFront distribution domain name |
| <a name="output_cloudfront_url"></a> [cloudfront\_url](#output\_cloudfront\_url) | CloudFront distribution URL |
| <a name="output_deploy_lambda_command"></a> [deploy\_lambda\_command](#output\_deploy\_lambda\_command) | Command to deploy a Lambda function |
| <a name="output_deploy_spa_command"></a> [deploy\_spa\_command](#output\_deploy\_spa\_command) | Commands to deploy SPA to CloudFront |
| <a name="output_developer_role_arn"></a> [developer\_role\_arn](#output\_developer\_role\_arn) | ARN of the developer deployment role |
| <a name="output_developer_role_assume_command"></a> [developer\_role\_assume\_command](#output\_developer\_role\_assume\_command) | AWS CLI command to assume the developer role |
| <a name="output_developer_role_profile_config"></a> [developer\_role\_profile\_config](#output\_developer\_role\_profile\_config) | AWS CLI profile configuration for developer role |
| <a name="output_eligibility_test_info_lambda_arn"></a> [eligibility\_test\_info\_lambda\_arn](#output\_eligibility\_test\_info\_lambda\_arn) | ARN of the eligibility-test-info Lambda |
| <a name="output_hello_world_lambda_arn"></a> [hello\_world\_lambda\_arn](#output\_hello\_world\_lambda\_arn) | ARN of the hello-world Lambda |
| <a name="output_lambda_execution_role_arn"></a> [lambda\_execution\_role\_arn](#output\_lambda\_execution\_role\_arn) | ARN of the Lambda execution role |
| <a name="output_order_router_lambda_arn"></a> [order\_router\_lambda\_arn](#output\_order\_router\_lambda\_arn) | ARN of the order-router Lambda |
| <a name="output_spa_bucket_arn"></a> [spa\_bucket\_arn](#output\_spa\_bucket\_arn) | S3 bucket ARN for SPA static assets |
| <a name="output_spa_bucket_id"></a> [spa\_bucket\_id](#output\_spa\_bucket\_id) | S3 bucket ID for SPA static assets |
<!-- END_TF_DOCS -->