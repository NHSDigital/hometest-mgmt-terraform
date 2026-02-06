# waf

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
| [aws_cloudwatch_log_group.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_kms_alias.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_wafv2_ip_set.allowlist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_ip_set.blocklist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_web_acl.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_countries"></a> [allowed\_countries](#input\_allowed\_countries) | List of country codes to allow (ISO 3166-1 alpha-2, e.g., GB, US) | `list(string)` | <pre>[<br/>  "GB"<br/>]</pre> | no |
| <a name="input_allowed_ip_addresses"></a> [allowed\_ip\_addresses](#input\_allowed\_ip\_addresses) | List of allowed IP addresses in CIDR notation (e.g., 1.2.3.4/32) | `list(string)` | `[]` | no |
| <a name="input_api_gateway_stage_arn"></a> [api\_gateway\_stage\_arn](#input\_api\_gateway\_stage\_arn) | ARN of the API Gateway stage to associate with WAF | `string` | `""` | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_account_shortname"></a> [aws\_account\_shortname](#input\_aws\_account\_shortname) | AWS account short name/alias for resource naming | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_blocked_ip_addresses"></a> [blocked\_ip\_addresses](#input\_blocked\_ip\_addresses) | List of blocked IP addresses in CIDR notation (e.g., 1.2.3.4/32) | `list(string)` | `[]` | no |
| <a name="input_common_rules_excluded"></a> [common\_rules\_excluded](#input\_common\_rules\_excluded) | List of rules from AWSManagedRulesCommonRuleSet to exclude (set to count mode) | `list(string)` | `[]` | no |
| <a name="input_enable_geo_restriction"></a> [enable\_geo\_restriction](#input\_enable\_geo\_restriction) | Enable geographic restriction (block all countries except allowed) | `bool` | `false` | no |
| <a name="input_enable_ip_allowlist"></a> [enable\_ip\_allowlist](#input\_enable\_ip\_allowlist) | Enable IP allowlist rule | `bool` | `false` | no |
| <a name="input_enable_ip_blocklist"></a> [enable\_ip\_blocklist](#input\_enable\_ip\_blocklist) | Enable IP blocklist rule | `bool` | `false` | no |
| <a name="input_enable_linux_rules"></a> [enable\_linux\_rules](#input\_enable\_linux\_rules) | Enable AWS Managed Rules for Linux OS | `bool` | `true` | no |
| <a name="input_enable_rate_limiting"></a> [enable\_rate\_limiting](#input\_enable\_rate\_limiting) | Enable rate limiting rule | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., dev, staging, prod) | `string` | n/a | yes |
| <a name="input_kms_key_deletion_window_days"></a> [kms\_key\_deletion\_window\_days](#input\_kms\_key\_deletion\_window\_days) | Number of days before KMS key is deleted | `number` | `30` | no |
| <a name="input_log_all_requests"></a> [log\_all\_requests](#input\_log\_all\_requests) | Log all requests (true) or only blocked/counted requests (false) | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | n/a | yes |
| <a name="input_rate_limit"></a> [rate\_limit](#input\_rate\_limit) | Maximum number of requests per 5-minute period per IP | `number` | `2000` | no |
| <a name="input_redacted_fields"></a> [redacted\_fields](#input\_redacted\_fields) | List of fields to redact in WAF logs | <pre>list(object({<br/>    type = string<br/>    name = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "name": "authorization",<br/>    "type": "single_header"<br/>  },<br/>  {<br/>    "name": "cookie",<br/>    "type": "single_header"<br/>  }<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_association_id"></a> [api\_gateway\_association\_id](#output\_api\_gateway\_association\_id) | The ID of the WAF association with API Gateway |
| <a name="output_ip_allowlist_arn"></a> [ip\_allowlist\_arn](#output\_ip\_allowlist\_arn) | The ARN of the IP allowlist set |
| <a name="output_ip_blocklist_arn"></a> [ip\_blocklist\_arn](#output\_ip\_blocklist\_arn) | The ARN of the IP blocklist set |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key for WAF logs |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The ID of the KMS key for WAF logs |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | The ARN of the CloudWatch Log Group for WAF logs |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | The name of the CloudWatch Log Group for WAF logs |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | The ARN of the WAF Web ACL |
| <a name="output_web_acl_capacity"></a> [web\_acl\_capacity](#output\_web\_acl\_capacity) | The Web ACL capacity units (WCUs) used by this Web ACL |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | The ID of the WAF Web ACL |
| <a name="output_web_acl_name"></a> [web\_acl\_name](#output\_web\_acl\_name) | The name of the WAF Web ACL |
<!-- END_TF_DOCS -->
