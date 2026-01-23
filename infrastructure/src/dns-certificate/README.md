# dns-certificate

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
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudwatch_metric_alarm.health_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_route53_health_check.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_health_check) | resource |
| [aws_route53_record.api_gateway_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_domain_names"></a> [additional\_domain\_names](#input\_additional\_domain\_names) | Additional domain names (SANs) for the certificate | `list(string)` | `[]` | no |
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | List of ARNs to notify when alarm triggers | `list(string)` | `[]` | no |
| <a name="input_api_gateway_regional_domain_name"></a> [api\_gateway\_regional\_domain\_name](#input\_api\_gateway\_regional\_domain\_name) | Regional domain name of the API Gateway custom domain | `string` | `""` | no |
| <a name="input_api_gateway_regional_zone_id"></a> [api\_gateway\_regional\_zone\_id](#input\_api\_gateway\_regional\_zone\_id) | Regional zone ID of the API Gateway custom domain | `string` | `""` | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_account_shortname"></a> [aws\_account\_shortname](#input\_aws\_account\_shortname) | AWS account short name/alias for resource naming | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_base_domain_name"></a> [base\_domain\_name](#input\_base\_domain\_name) | Base domain name (e.g., hometest.service.nhs.uk) | `string` | `"hometest.service.nhs.uk"` | no |
| <a name="input_create_api_gateway_record"></a> [create\_api\_gateway\_record](#input\_create\_api\_gateway\_record) | Create Route53 A record alias to API Gateway | `bool` | `false` | no |
| <a name="input_create_health_check"></a> [create\_health\_check](#input\_create\_health\_check) | Create Route53 health check for the endpoint | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., dev, staging, prod) | `string` | n/a | yes |
| <a name="input_health_check_failure_threshold"></a> [health\_check\_failure\_threshold](#input\_health\_check\_failure\_threshold) | Number of consecutive failures before unhealthy | `number` | `3` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Path for the health check | `string` | `"/health"` | no |
| <a name="input_health_check_request_interval"></a> [health\_check\_request\_interval](#input\_health\_check\_request\_interval) | Seconds between health checks (10 or 30) | `number` | `30` | no |
| <a name="input_ok_actions"></a> [ok\_actions](#input\_ok\_actions) | List of ARNs to notify when alarm returns to OK | `list(string)` | `[]` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint_url"></a> [api\_endpoint\_url](#output\_api\_endpoint\_url) | The URL of the API endpoint |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | The ARN of the ACM certificate |
| <a name="output_certificate_domain_name"></a> [certificate\_domain\_name](#output\_certificate\_domain\_name) | The domain name of the certificate |
| <a name="output_certificate_status"></a> [certificate\_status](#output\_certificate\_status) | The status of the certificate |
| <a name="output_certificate_validated"></a> [certificate\_validated](#output\_certificate\_validated) | Whether the certificate has been validated |
| <a name="output_certificate_validation_emails"></a> [certificate\_validation\_emails](#output\_certificate\_validation\_emails) | Email addresses for certificate validation (if email validation) |
| <a name="output_environment_fqdn"></a> [environment\_fqdn](#output\_environment\_fqdn) | The fully qualified domain name for this environment |
| <a name="output_health_check_id"></a> [health\_check\_id](#output\_health\_check\_id) | The ID of the Route53 health check |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | The ID of the Route53 hosted zone |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | The name of the Route53 hosted zone |
<!-- END_TF_DOCS -->
