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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_aws.us_east_1"></a> [aws.us\_east\_1](#provider\_aws.us\_east\_1) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudwatch_log_group.waf_regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.developer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.developer_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route53_record.regional_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.deployment_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.deployment_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.deployment_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.deployment_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.deployment_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.api_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.api_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_wafv2_web_acl.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifact_retention_days"></a> [artifact\_retention\_days](#input\_artifact\_retention\_days) | Days to retain old artifact versions | `number` | `30` | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_create_acm_certificates"></a> [create\_acm\_certificates](#input\_create\_acm\_certificates) | Whether to create ACM certificates | `bool` | `true` | no |
| <a name="input_developer_account_arns"></a> [developer\_account\_arns](#input\_developer\_account\_arns) | List of AWS account ARNs allowed to assume the developer role | `list(string)` | `[]` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Base domain name for certificates (e.g., hometest.service.nhs.uk) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (core for shared services) | `string` | `"core"` | no |
| <a name="input_kms_deletion_window_days"></a> [kms\_deletion\_window\_days](#input\_kms\_deletion\_window\_days) | Number of days before KMS key is deleted | `number` | `30` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project | `string` | n/a | yes |
| <a name="input_require_mfa"></a> [require\_mfa](#input\_require\_mfa) | Require MFA for developer role assumption | `bool` | `true` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 zone ID for DNS validation | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_waf_log_retention_days"></a> [waf\_log\_retention\_days](#input\_waf\_log\_retention\_days) | Days to retain WAF logs | `number` | `30` | no |
| <a name="input_waf_rate_limit"></a> [waf\_rate\_limit](#input\_waf\_rate\_limit) | Rate limit for WAF (requests per 5 minutes per IP) | `number` | `2000` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_cloudfront_certificate_arn"></a> [acm\_cloudfront\_certificate\_arn](#output\_acm\_cloudfront\_certificate\_arn) | ARN of the CloudFront ACM certificate (us-east-1) |
| <a name="output_acm_cloudfront_certificate_validated"></a> [acm\_cloudfront\_certificate\_validated](#output\_acm\_cloudfront\_certificate\_validated) | Whether the CloudFront certificate has been validated |
| <a name="output_acm_regional_certificate_arn"></a> [acm\_regional\_certificate\_arn](#output\_acm\_regional\_certificate\_arn) | ARN of the regional ACM certificate (for API Gateway) |
| <a name="output_acm_regional_certificate_validated"></a> [acm\_regional\_certificate\_validated](#output\_acm\_regional\_certificate\_validated) | Whether the regional certificate has been validated |
| <a name="output_api_config_secret_arn"></a> [api\_config\_secret\_arn](#output\_api\_config\_secret\_arn) | ARN of the API config secret |
| <a name="output_api_config_secret_name"></a> [api\_config\_secret\_name](#output\_api\_config\_secret\_name) | Name of the API config secret |
| <a name="output_deployment_artifacts_bucket_arn"></a> [deployment\_artifacts\_bucket\_arn](#output\_deployment\_artifacts\_bucket\_arn) | ARN of the deployment artifacts S3 bucket |
| <a name="output_deployment_artifacts_bucket_domain"></a> [deployment\_artifacts\_bucket\_domain](#output\_deployment\_artifacts\_bucket\_domain) | Domain name of the deployment artifacts bucket |
| <a name="output_deployment_artifacts_bucket_id"></a> [deployment\_artifacts\_bucket\_id](#output\_deployment\_artifacts\_bucket\_id) | ID of the deployment artifacts S3 bucket |
| <a name="output_developer_role_arn"></a> [developer\_role\_arn](#output\_developer\_role\_arn) | ARN of the developer deployment role |
| <a name="output_developer_role_name"></a> [developer\_role\_name](#output\_developer\_role\_name) | Name of the developer deployment role |
| <a name="output_kms_key_alias_arn"></a> [kms\_key\_alias\_arn](#output\_kms\_key\_alias\_arn) | ARN of the KMS key alias |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the shared KMS key |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | ID of the shared KMS key |
| <a name="output_shared_config"></a> [shared\_config](#output\_shared\_config) | All shared service configuration for app deployments |
| <a name="output_waf_cloudfront_arn"></a> [waf\_cloudfront\_arn](#output\_waf\_cloudfront\_arn) | ARN of the CloudFront WAF Web ACL (for CloudFront distributions) |
| <a name="output_waf_cloudfront_id"></a> [waf\_cloudfront\_id](#output\_waf\_cloudfront\_id) | ID of the CloudFront WAF Web ACL |
| <a name="output_waf_regional_arn"></a> [waf\_regional\_arn](#output\_waf\_regional\_arn) | ARN of the regional WAF Web ACL (for API Gateway) |
| <a name="output_waf_regional_id"></a> [waf\_regional\_id](#output\_waf\_regional\_id) | ID of the regional WAF Web ACL |
<!-- END_TF_DOCS -->
