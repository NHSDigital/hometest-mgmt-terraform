# iam-developer-role

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.28.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.developer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.api_gateway_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.cloudtrail_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.cloudwatch_logs_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.cloudwatch_metrics_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.custom_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.iam_read_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.xray_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_iam_statements"></a> [additional\_iam\_statements](#input\_additional\_iam\_statements) | Additional IAM policy statements to attach to the developer role | <pre>list(object({<br/>    Sid      = string<br/>    Effect   = string<br/>    Action   = list(string)<br/>    Resource = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_aft_external_id"></a> [aft\_external\_id](#input\_aft\_external\_id) | External ID for AFT role assumption (for security) | `string` | `""` | no |
| <a name="input_aft_management_account_id"></a> [aft\_management\_account\_id](#input\_aft\_management\_account\_id) | AWS Account ID of the AFT management account (for cross-account trust) | `string` | `""` | no |
| <a name="input_allowed_teams"></a> [allowed\_teams](#input\_allowed\_teams) | List of team tags allowed to assume this role (for SSO trust) | `list(string)` | <pre>[<br/>  "developers"<br/>]</pre> | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_account_shortname"></a> [aws\_account\_shortname](#input\_aws\_account\_shortname) | AWS account short name/alias for resource naming | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_enable_account_trust"></a> [enable\_account\_trust](#input\_enable\_account\_trust) | Enable trust from account root (for testing - not recommended for production) | `bool` | `false` | no |
| <a name="input_enable_aft_trust"></a> [enable\_aft\_trust](#input\_enable\_aft\_trust) | Enable trust for AWS Account Factory for Terraform (AFT) | `bool` | `true` | no |
| <a name="input_enable_github_oidc_trust"></a> [enable\_github\_oidc\_trust](#input\_enable\_github\_oidc\_trust) | Enable trust for GitHub Actions OIDC | `bool` | `false` | no |
| <a name="input_enable_sso_trust"></a> [enable\_sso\_trust](#input\_enable\_sso\_trust) | Enable trust for AWS SSO / Identity Center users | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., dev, staging, prod) - used for scoping permissions | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub repository in format 'owner/repo-name' for OIDC trust | `string` | `""` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration in seconds (1 hour to 12 hours) | `number` | `3600` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aft_config"></a> [aft\_config](#output\_aft\_config) | Configuration block for AWS AFT integration |
| <a name="output_aft_role_reference"></a> [aft\_role\_reference](#output\_aft\_role\_reference) | Role ARN formatted for AWS AFT account request |
| <a name="output_permission_scope"></a> [permission\_scope](#output\_permission\_scope) | Description of the permission scope for this role |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The ARN of the developer IAM role |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | The ID of the developer IAM role |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the developer IAM role |
| <a name="output_role_unique_id"></a> [role\_unique\_id](#output\_role\_unique\_id) | The unique ID of the developer IAM role |
<!-- END_TF_DOCS -->
