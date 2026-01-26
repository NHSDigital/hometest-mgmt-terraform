# application

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
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.lambda_duration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_throttles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_key.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_alias.live](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_alias) | resource |
| [aws_lambda_function.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_s3_bucket.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_iam_statements"></a> [additional\_iam\_statements](#input\_additional\_iam\_statements) | Additional IAM policy statements for the Lambda execution role | <pre>list(object({<br/>    Effect   = string<br/>    Action   = list(string)<br/>    Resource = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | List of ARNs to notify when alarm triggers | `list(string)` | `[]` | no |
| <a name="input_alias_function_version"></a> [alias\_function\_version](#input\_alias\_function\_version) | Lambda function version for the alias (empty for $LATEST) | `string` | `""` | no |
| <a name="input_alias_name"></a> [alias\_name](#input\_alias\_name) | Name of the Lambda alias | `string` | `"live"` | no |
| <a name="input_artifacts_retention_days"></a> [artifacts\_retention\_days](#input\_artifacts\_retention\_days) | Number of days to retain old artifact versions | `number` | `30` | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_account_shortname"></a> [aws\_account\_shortname](#input\_aws\_account\_shortname) | AWS account short name/alias for resource naming | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Number of days to retain CloudWatch logs for Lambda function | `number` | `30` | no |
| <a name="input_code_signing_config_arn"></a> [code\_signing\_config\_arn](#input\_code\_signing\_config\_arn) | ARN of the code signing configuration for Lambda (optional - for compliance) | `string` | `""` | no |
| <a name="input_create_alarms"></a> [create\_alarms](#input\_create\_alarms) | Create CloudWatch alarms for the Lambda function | `bool` | `true` | no |
| <a name="input_create_alias"></a> [create\_alias](#input\_create\_alias) | Create a Lambda alias for stable endpoint | `bool` | `false` | no |
| <a name="input_create_artifacts_bucket"></a> [create\_artifacts\_bucket](#input\_create\_artifacts\_bucket) | Create an S3 bucket for Lambda artifacts | `bool` | `true` | no |
| <a name="input_dead_letter_queue_arn"></a> [dead\_letter\_queue\_arn](#input\_dead\_letter\_queue\_arn) | ARN of the SQS queue or SNS topic for dead letter queue | `string` | `""` | no |
| <a name="input_enable_vpc"></a> [enable\_vpc](#input\_enable\_vpc) | Deploy Lambda function in VPC | `bool` | `false` | no |
| <a name="input_enable_xray_tracing"></a> [enable\_xray\_tracing](#input\_enable\_xray\_tracing) | Enable AWS X-Ray tracing for Lambda | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., dev, staging, prod) | `string` | n/a | yes |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Environment variables for the Lambda function | `map(string)` | `{}` | no |
| <a name="input_error_threshold"></a> [error\_threshold](#input\_error\_threshold) | Error count threshold for alarm | `number` | `5` | no |
| <a name="input_kms_key_deletion_window_days"></a> [kms\_key\_deletion\_window\_days](#input\_kms\_key\_deletion\_window\_days) | Number of days before KMS key is deleted | `number` | `30` | no |
| <a name="input_lambda_description"></a> [lambda\_description](#input\_lambda\_description) | Description of the Lambda function | `string` | `"API Lambda function"` | no |
| <a name="input_lambda_filename"></a> [lambda\_filename](#input\_lambda\_filename) | Path to the local Lambda deployment package (zip file) | `string` | `""` | no |
| <a name="input_lambda_handler"></a> [lambda\_handler](#input\_lambda\_handler) | Lambda function handler (e.g., index.handler) | `string` | `"index.handler"` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda function memory size in MB | `number` | `256` | no |
| <a name="input_lambda_name"></a> [lambda\_name](#input\_lambda\_name) | Name suffix for the Lambda function (will be prefixed with resource\_prefix) | `string` | `"api"` | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | Lambda function runtime | `string` | `"nodejs20.x"` | no |
| <a name="input_lambda_s3_bucket"></a> [lambda\_s3\_bucket](#input\_lambda\_s3\_bucket) | S3 bucket containing the Lambda deployment package | `string` | `""` | no |
| <a name="input_lambda_s3_key"></a> [lambda\_s3\_key](#input\_lambda\_s3\_key) | S3 key of the Lambda deployment package | `string` | `""` | no |
| <a name="input_lambda_s3_object_version"></a> [lambda\_s3\_object\_version](#input\_lambda\_s3\_object\_version) | S3 object version of the Lambda deployment package | `string` | `""` | no |
| <a name="input_lambda_source_code_hash"></a> [lambda\_source\_code\_hash](#input\_lambda\_source\_code\_hash) | Base64-encoded SHA256 hash of the package (for update detection) | `string` | `null` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda function timeout in seconds | `number` | `30` | no |
| <a name="input_ok_actions"></a> [ok\_actions](#input\_ok\_actions) | List of ARNs to notify when alarm returns to OK | `list(string)` | `[]` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | n/a | yes |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Reserved concurrent executions for Lambda (-1 for no reservation) | `number` | `-1` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of VPC security group IDs for Lambda | `list(string)` | `[]` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of VPC subnet IDs for Lambda | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_artifacts_bucket_arn"></a> [artifacts\_bucket\_arn](#output\_artifacts\_bucket\_arn) | The ARN of the S3 bucket for Lambda artifacts |
| <a name="output_artifacts_bucket_domain_name"></a> [artifacts\_bucket\_domain\_name](#output\_artifacts\_bucket\_domain\_name) | The domain name of the S3 bucket for Lambda artifacts |
| <a name="output_artifacts_bucket_id"></a> [artifacts\_bucket\_id](#output\_artifacts\_bucket\_id) | The ID of the S3 bucket for Lambda artifacts |
| <a name="output_duration_alarm_arn"></a> [duration\_alarm\_arn](#output\_duration\_alarm\_arn) | The ARN of the Lambda duration alarm |
| <a name="output_error_alarm_arn"></a> [error\_alarm\_arn](#output\_error\_alarm\_arn) | The ARN of the Lambda errors alarm |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key for Lambda |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The ID of the KMS key for Lambda |
| <a name="output_lambda_alias_arn"></a> [lambda\_alias\_arn](#output\_lambda\_alias\_arn) | The ARN of the Lambda alias |
| <a name="output_lambda_alias_invoke_arn"></a> [lambda\_alias\_invoke\_arn](#output\_lambda\_alias\_invoke\_arn) | The invoke ARN of the Lambda alias |
| <a name="output_lambda_execution_role_arn"></a> [lambda\_execution\_role\_arn](#output\_lambda\_execution\_role\_arn) | The ARN of the Lambda execution role |
| <a name="output_lambda_execution_role_name"></a> [lambda\_execution\_role\_name](#output\_lambda\_execution\_role\_name) | The name of the Lambda execution role |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_lambda_invoke_arn"></a> [lambda\_invoke\_arn](#output\_lambda\_invoke\_arn) | The invoke ARN of the Lambda function (for API Gateway integration) |
| <a name="output_lambda_last_modified"></a> [lambda\_last\_modified](#output\_lambda\_last\_modified) | The last modified date of the Lambda function |
| <a name="output_lambda_qualified_arn"></a> [lambda\_qualified\_arn](#output\_lambda\_qualified\_arn) | The qualified ARN of the Lambda function (with version) |
| <a name="output_lambda_source_code_size"></a> [lambda\_source\_code\_size](#output\_lambda\_source\_code\_size) | The size of the Lambda function package in bytes |
| <a name="output_lambda_version"></a> [lambda\_version](#output\_lambda\_version) | The version of the Lambda function |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | The ARN of the CloudWatch Log Group |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | The name of the CloudWatch Log Group |
| <a name="output_throttle_alarm_arn"></a> [throttle\_alarm\_arn](#output\_throttle\_alarm\_arn) | The ARN of the Lambda throttles alarm |
<!-- END_TF_DOCS -->
