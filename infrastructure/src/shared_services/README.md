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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.33.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.33.0 |
| <a name="provider_aws.us_east_1"></a> [aws.us\_east\_1](#provider\_aws.us\_east\_1) | ~> 6.33.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sns_alerts"></a> [sns\_alerts](#module\_sns\_alerts) | ../../modules/sns | n/a |
| <a name="module_sqs_events"></a> [sqs\_events](#module\_sqs\_events) | ../../modules/sqs | n/a |
| <a name="module_sqs_notifications"></a> [sqs\_notifications](#module\_sqs\_notifications) | ../../modules/sqs | n/a |
| <a name="module_sqs_orders"></a> [sqs\_orders](#module\_sqs\_orders) | ../../modules/sqs | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudwatch_log_group.waf_regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_identity_pool.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool) | resource |
| [aws_cognito_identity_pool_roles_attachment.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool_roles_attachment) | resource |
| [aws_cognito_resource_server.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_resource_server) | resource |
| [aws_cognito_resource_server.orders](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_resource_server) | resource |
| [aws_cognito_resource_server.results](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_resource_server) | resource |
| [aws_cognito_user_pool.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.internal_test_client_m2m](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_client.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_client.preventex_m2m](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_client.sh24_m2m](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [aws_iam_role.cognito_authenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cognito_unauthenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.developer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cognito_authenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.cognito_unauthenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.developer_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_resourcegroups_group.rg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/resourcegroups_group) | resource |
| [aws_route53_record.regional_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.api_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.api_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_wafv2_web_acl.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_iam_policy_document.cognito_identity_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cognito_identity_unauthenticated_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID for resources | `string` | n/a | yes |
| <a name="input_aws_account_shortname"></a> [aws\_account\_shortname](#input\_aws\_account\_shortname) | AWS account short name/alias for resource naming | `string` | n/a | yes |
| <a name="input_aws_allowed_regions"></a> [aws\_allowed\_regions](#input\_aws\_allowed\_regions) | List of AWS regions allowed for resource deployment | `list(string)` | <pre>[<br/>  "eu-west-2",<br/>  "us-east-1"<br/>]</pre> | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resources | `string` | n/a | yes |
| <a name="input_cognito_access_token_validity"></a> [cognito\_access\_token\_validity](#input\_cognito\_access\_token\_validity) | Access token validity in time units | `number` | `60` | no |
| <a name="input_cognito_access_token_validity_units"></a> [cognito\_access\_token\_validity\_units](#input\_cognito\_access\_token\_validity\_units) | Time unit for access token validity (seconds, minutes, hours, days) | `string` | `"minutes"` | no |
| <a name="input_cognito_allow_admin_create_user_only"></a> [cognito\_allow\_admin\_create\_user\_only](#input\_cognito\_allow\_admin\_create\_user\_only) | Only allow administrators to create users (disable self-registration) | `bool` | `false` | no |
| <a name="input_cognito_allow_classic_flow"></a> [cognito\_allow\_classic\_flow](#input\_cognito\_allow\_classic\_flow) | Allow classic (basic) authentication flow | `bool` | `false` | no |
| <a name="input_cognito_allow_unauthenticated_identities"></a> [cognito\_allow\_unauthenticated\_identities](#input\_cognito\_allow\_unauthenticated\_identities) | Allow unauthenticated identities in the identity pool | `bool` | `false` | no |
| <a name="input_cognito_allowed_oauth_flows"></a> [cognito\_allowed\_oauth\_flows](#input\_cognito\_allowed\_oauth\_flows) | Allowed OAuth flows (code, implicit, client\_credentials) | `list(string)` | <pre>[<br/>  "code"<br/>]</pre> | no |
| <a name="input_cognito_allowed_oauth_flows_user_pool_client"></a> [cognito\_allowed\_oauth\_flows\_user\_pool\_client](#input\_cognito\_allowed\_oauth\_flows\_user\_pool\_client) | Whether OAuth flows are allowed for the user pool client | `bool` | `true` | no |
| <a name="input_cognito_allowed_oauth_scopes"></a> [cognito\_allowed\_oauth\_scopes](#input\_cognito\_allowed\_oauth\_scopes) | Allowed OAuth scopes | `list(string)` | <pre>[<br/>  "email",<br/>  "openid",<br/>  "profile"<br/>]</pre> | no |
| <a name="input_cognito_attributes_require_verification"></a> [cognito\_attributes\_require\_verification](#input\_cognito\_attributes\_require\_verification) | Attributes that require verification before update | `list(string)` | <pre>[<br/>  "email"<br/>]</pre> | no |
| <a name="input_cognito_auto_verified_attributes"></a> [cognito\_auto\_verified\_attributes](#input\_cognito\_auto\_verified\_attributes) | Attributes to be auto-verified (email, phone\_number, or both) | `list(string)` | <pre>[<br/>  "email"<br/>]</pre> | no |
| <a name="input_cognito_callback_urls"></a> [cognito\_callback\_urls](#input\_cognito\_callback\_urls) | List of allowed callback URLs for OAuth | `list(string)` | `[]` | no |
| <a name="input_cognito_custom_attributes"></a> [cognito\_custom\_attributes](#input\_cognito\_custom\_attributes) | List of custom user attributes | <pre>list(object({<br/>    name                     = string<br/>    attribute_data_type      = string # String, Number, DateTime, Boolean<br/>    developer_only_attribute = optional(bool, false)<br/>    mutable                  = optional(bool, true)<br/>    required                 = optional(bool, false)<br/>    min_length               = optional(number, 0)<br/>    max_length               = optional(number, 2048)<br/>    min_value                = optional(number)<br/>    max_value                = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_cognito_custom_domain"></a> [cognito\_custom\_domain](#input\_cognito\_custom\_domain) | Custom domain for Cognito hosted UI (leave empty for default AWS domain) | `string` | `""` | no |
| <a name="input_cognito_deletion_protection"></a> [cognito\_deletion\_protection](#input\_cognito\_deletion\_protection) | Enable deletion protection for the user pool | `bool` | `true` | no |
| <a name="input_cognito_device_challenge_required"></a> [cognito\_device\_challenge\_required](#input\_cognito\_device\_challenge\_required) | Require device challenge on new devices | `bool` | `true` | no |
| <a name="input_cognito_device_remember_on_prompt"></a> [cognito\_device\_remember\_on\_prompt](#input\_cognito\_device\_remember\_on\_prompt) | Only remember devices when user opts in | `bool` | `true` | no |
| <a name="input_cognito_domain_certificate_arn"></a> [cognito\_domain\_certificate\_arn](#input\_cognito\_domain\_certificate\_arn) | ACM certificate ARN for custom domain (required if using custom domain) | `string` | `null` | no |
| <a name="input_cognito_email_sending_account"></a> [cognito\_email\_sending\_account](#input\_cognito\_email\_sending\_account) | Email sending account type (COGNITO\_DEFAULT or DEVELOPER) | `string` | `"COGNITO_DEFAULT"` | no |
| <a name="input_cognito_enable_propagate_user_context"></a> [cognito\_enable\_propagate\_user\_context](#input\_cognito\_enable\_propagate\_user\_context) | Enable propagation of additional user context data | `bool` | `false` | no |
| <a name="input_cognito_enable_token_revocation"></a> [cognito\_enable\_token\_revocation](#input\_cognito\_enable\_token\_revocation) | Enable token revocation | `bool` | `true` | no |
| <a name="input_cognito_explicit_auth_flows"></a> [cognito\_explicit\_auth\_flows](#input\_cognito\_explicit\_auth\_flows) | Explicit authentication flows enabled | `list(string)` | <pre>[<br/>  "ALLOW_REFRESH_TOKEN_AUTH",<br/>  "ALLOW_USER_SRP_AUTH"<br/>]</pre> | no |
| <a name="input_cognito_from_email_address"></a> [cognito\_from\_email\_address](#input\_cognito\_from\_email\_address) | From email address for Cognito emails (requires DEVELOPER email sending account) | `string` | `null` | no |
| <a name="input_cognito_generate_client_secret"></a> [cognito\_generate\_client\_secret](#input\_cognito\_generate\_client\_secret) | Generate a client secret for the app client | `bool` | `true` | no |
| <a name="input_cognito_id_token_validity"></a> [cognito\_id\_token\_validity](#input\_cognito\_id\_token\_validity) | ID token validity in time units | `number` | `60` | no |
| <a name="input_cognito_id_token_validity_units"></a> [cognito\_id\_token\_validity\_units](#input\_cognito\_id\_token\_validity\_units) | Time unit for ID token validity (seconds, minutes, hours, days) | `string` | `"minutes"` | no |
| <a name="input_cognito_invite_email_message"></a> [cognito\_invite\_email\_message](#input\_cognito\_invite\_email\_message) | Email message for user invitation emails. Must contain {username} and {####} placeholders. | `string` | `"Your username is {username} and temporary password is {####}."` | no |
| <a name="input_cognito_invite_email_subject"></a> [cognito\_invite\_email\_subject](#input\_cognito\_invite\_email\_subject) | Email subject for user invitation emails | `string` | `"Your temporary password"` | no |
| <a name="input_cognito_invite_sms_message"></a> [cognito\_invite\_sms\_message](#input\_cognito\_invite\_sms\_message) | SMS message for user invitation. Must contain {username} and {####} placeholders. | `string` | `"Your username is {username} and temporary password is {####}."` | no |
| <a name="input_cognito_logout_urls"></a> [cognito\_logout\_urls](#input\_cognito\_logout\_urls) | List of allowed logout URLs | `list(string)` | `[]` | no |
| <a name="input_cognito_mfa_configuration"></a> [cognito\_mfa\_configuration](#input\_cognito\_mfa\_configuration) | MFA configuration (OFF, ON, OPTIONAL) | `string` | `"OPTIONAL"` | no |
| <a name="input_cognito_password_minimum_length"></a> [cognito\_password\_minimum\_length](#input\_cognito\_password\_minimum\_length) | Minimum password length | `number` | `12` | no |
| <a name="input_cognito_password_require_lowercase"></a> [cognito\_password\_require\_lowercase](#input\_cognito\_password\_require\_lowercase) | Require lowercase letters in password | `bool` | `true` | no |
| <a name="input_cognito_password_require_numbers"></a> [cognito\_password\_require\_numbers](#input\_cognito\_password\_require\_numbers) | Require numbers in password | `bool` | `true` | no |
| <a name="input_cognito_password_require_symbols"></a> [cognito\_password\_require\_symbols](#input\_cognito\_password\_require\_symbols) | Require symbols in password | `bool` | `true` | no |
| <a name="input_cognito_password_require_uppercase"></a> [cognito\_password\_require\_uppercase](#input\_cognito\_password\_require\_uppercase) | Require uppercase letters in password | `bool` | `true` | no |
| <a name="input_cognito_prevent_user_existence_errors"></a> [cognito\_prevent\_user\_existence\_errors](#input\_cognito\_prevent\_user\_existence\_errors) | How to handle user existence errors (LEGACY or ENABLED) | `string` | `"ENABLED"` | no |
| <a name="input_cognito_read_attributes"></a> [cognito\_read\_attributes](#input\_cognito\_read\_attributes) | List of user pool attributes the app client can read | `list(string)` | <pre>[<br/>  "email",<br/>  "email_verified",<br/>  "name"<br/>]</pre> | no |
| <a name="input_cognito_refresh_token_validity"></a> [cognito\_refresh\_token\_validity](#input\_cognito\_refresh\_token\_validity) | Refresh token validity in time units | `number` | `30` | no |
| <a name="input_cognito_refresh_token_validity_units"></a> [cognito\_refresh\_token\_validity\_units](#input\_cognito\_refresh\_token\_validity\_units) | Time unit for refresh token validity (seconds, minutes, hours, days) | `string` | `"days"` | no |
| <a name="input_cognito_resource_server_identifier"></a> [cognito\_resource\_server\_identifier](#input\_cognito\_resource\_server\_identifier) | Identifier for the resource server (defaults to route53\_zone\_name) | `string` | `""` | no |
| <a name="input_cognito_resource_server_scopes"></a> [cognito\_resource\_server\_scopes](#input\_cognito\_resource\_server\_scopes) | List of scopes for the resource server | <pre>list(object({<br/>    name        = string<br/>    description = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cognito_server_side_token_check"></a> [cognito\_server\_side\_token\_check](#input\_cognito\_server\_side\_token\_check) | Enable server-side token validation | `bool` | `true` | no |
| <a name="input_cognito_ses_email_identity_arn"></a> [cognito\_ses\_email\_identity\_arn](#input\_cognito\_ses\_email\_identity\_arn) | ARN of SES verified email identity (required if email\_sending\_account is DEVELOPER) | `string` | `null` | no |
| <a name="input_cognito_supported_identity_providers"></a> [cognito\_supported\_identity\_providers](#input\_cognito\_supported\_identity\_providers) | Supported identity providers (COGNITO, Facebook, Google, etc.) | `list(string)` | <pre>[<br/>  "COGNITO"<br/>]</pre> | no |
| <a name="input_cognito_temporary_password_validity_days"></a> [cognito\_temporary\_password\_validity\_days](#input\_cognito\_temporary\_password\_validity\_days) | Number of days temporary passwords are valid | `number` | `7` | no |
| <a name="input_cognito_username_case_sensitive"></a> [cognito\_username\_case\_sensitive](#input\_cognito\_username\_case\_sensitive) | Whether usernames are case sensitive | `bool` | `false` | no |
| <a name="input_cognito_verification_email_message"></a> [cognito\_verification\_email\_message](#input\_cognito\_verification\_email\_message) | Email message for verification emails. Must contain {####} placeholder. | `string` | `"Your verification code is {####}."` | no |
| <a name="input_cognito_verification_email_message_by_link"></a> [cognito\_verification\_email\_message\_by\_link](#input\_cognito\_verification\_email\_message\_by\_link) | Email message for verification link emails. Must contain {##Verify Email##} placeholder. | `string` | `"Please click the link below to verify your email address. {##Verify Email##}"` | no |
| <a name="input_cognito_verification_email_option"></a> [cognito\_verification\_email\_option](#input\_cognito\_verification\_email\_option) | Verification email option (CONFIRM\_WITH\_LINK or CONFIRM\_WITH\_CODE) | `string` | `"CONFIRM_WITH_CODE"` | no |
| <a name="input_cognito_verification_email_subject"></a> [cognito\_verification\_email\_subject](#input\_cognito\_verification\_email\_subject) | Email subject for verification emails | `string` | `"Your verification code"` | no |
| <a name="input_cognito_verification_email_subject_by_link"></a> [cognito\_verification\_email\_subject\_by\_link](#input\_cognito\_verification\_email\_subject\_by\_link) | Email subject for verification link emails | `string` | `"Verify your email"` | no |
| <a name="input_cognito_write_attributes"></a> [cognito\_write\_attributes](#input\_cognito\_write\_attributes) | List of user pool attributes the app client can write | `list(string)` | <pre>[<br/>  "email",<br/>  "name"<br/>]</pre> | no |
| <a name="input_create_acm_certificates"></a> [create\_acm\_certificates](#input\_create\_acm\_certificates) | Whether to create ACM certificates | `bool` | `true` | no |
| <a name="input_create_sqs_alarms"></a> [create\_sqs\_alarms](#input\_create\_sqs\_alarms) | Create CloudWatch alarms for SQS queues | `bool` | `true` | no |
| <a name="input_developer_account_arns"></a> [developer\_account\_arns](#input\_developer\_account\_arns) | List of AWS account ARNs allowed to assume the developer role | `list(string)` | `[]` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Base domain name for certificates (e.g., hometest.service.nhs.uk) | `string` | n/a | yes |
| <a name="input_enable_cognito"></a> [enable\_cognito](#input\_enable\_cognito) | Enable AWS Cognito User Pool for authentication | `bool` | `false` | no |
| <a name="input_enable_cognito_identity_pool"></a> [enable\_cognito\_identity\_pool](#input\_enable\_cognito\_identity\_pool) | Enable Cognito Identity Pool for federated identities | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (core for shared services) | `string` | `"core"` | no |
| <a name="input_events_queue_age_threshold"></a> [events\_queue\_age\_threshold](#input\_events\_queue\_age\_threshold) | Alarm threshold for oldest message age (seconds) | `number` | `600` | no |
| <a name="input_events_queue_depth_threshold"></a> [events\_queue\_depth\_threshold](#input\_events\_queue\_depth\_threshold) | Alarm threshold for queue depth | `number` | `2000` | no |
| <a name="input_events_queue_max_receive_count"></a> [events\_queue\_max\_receive\_count](#input\_events\_queue\_max\_receive\_count) | Max receives before moving to DLQ | `number` | `5` | no |
| <a name="input_events_queue_retention_seconds"></a> [events\_queue\_retention\_seconds](#input\_events\_queue\_retention\_seconds) | Message retention for events queue (seconds) | `number` | `604800` | no |
| <a name="input_events_queue_visibility_timeout"></a> [events\_queue\_visibility\_timeout](#input\_events\_queue\_visibility\_timeout) | Visibility timeout for events queue (seconds) | `number` | `120` | no |
| <a name="input_kms_deletion_window_days"></a> [kms\_deletion\_window\_days](#input\_kms\_deletion\_window\_days) | Number of days before KMS key is deleted | `number` | `30` | no |
| <a name="input_notifications_queue_age_threshold"></a> [notifications\_queue\_age\_threshold](#input\_notifications\_queue\_age\_threshold) | Alarm threshold for oldest message age (seconds) | `number` | `300` | no |
| <a name="input_notifications_queue_depth_threshold"></a> [notifications\_queue\_depth\_threshold](#input\_notifications\_queue\_depth\_threshold) | Alarm threshold for queue depth | `number` | `500` | no |
| <a name="input_notifications_queue_max_receive_count"></a> [notifications\_queue\_max\_receive\_count](#input\_notifications\_queue\_max\_receive\_count) | Max receives before moving to DLQ | `number` | `3` | no |
| <a name="input_notifications_queue_retention_seconds"></a> [notifications\_queue\_retention\_seconds](#input\_notifications\_queue\_retention\_seconds) | Message retention for notifications queue (seconds) | `number` | `345600` | no |
| <a name="input_notifications_queue_visibility_timeout"></a> [notifications\_queue\_visibility\_timeout](#input\_notifications\_queue\_visibility\_timeout) | Visibility timeout for notifications queue (seconds) | `number` | `180` | no |
| <a name="input_orders_queue_age_threshold"></a> [orders\_queue\_age\_threshold](#input\_orders\_queue\_age\_threshold) | Alarm threshold for oldest message age (seconds) | `number` | `600` | no |
| <a name="input_orders_queue_depth_threshold"></a> [orders\_queue\_depth\_threshold](#input\_orders\_queue\_depth\_threshold) | Alarm threshold for queue depth | `number` | `1000` | no |
| <a name="input_orders_queue_max_receive_count"></a> [orders\_queue\_max\_receive\_count](#input\_orders\_queue\_max\_receive\_count) | Max receives before moving to DLQ | `number` | `3` | no |
| <a name="input_orders_queue_retention_seconds"></a> [orders\_queue\_retention\_seconds](#input\_orders\_queue\_retention\_seconds) | Message retention for orders queue (seconds) | `number` | `345600` | no |
| <a name="input_orders_queue_visibility_timeout"></a> [orders\_queue\_visibility\_timeout](#input\_orders\_queue\_visibility\_timeout) | Visibility timeout for orders queue (seconds) | `number` | `300` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project | `string` | n/a | yes |
| <a name="input_require_mfa"></a> [require\_mfa](#input\_require\_mfa) | Require MFA for developer role assumption | `bool` | `true` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 zone ID for DNS validation | `string` | n/a | yes |
| <a name="input_sns_alerts_email_subscriptions"></a> [sns\_alerts\_email\_subscriptions](#input\_sns\_alerts\_email\_subscriptions) | List of email addresses to subscribe to the shared alerts SNS topic (requires subscription confirmation) | `list(string)` | `[]` | no |
| <a name="input_sqs_alarm_sns_topics"></a> [sqs\_alarm\_sns\_topics](#input\_sqs\_alarm\_sns\_topics) | List of SNS topic ARNs for SQS alarm notifications. If empty, defaults to the shared alerts SNS topic. | `list(string)` | `[]` | no |
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
| <a name="output_cognito_authenticated_role_arn"></a> [cognito\_authenticated\_role\_arn](#output\_cognito\_authenticated\_role\_arn) | The ARN of the IAM role for authenticated Cognito users |
| <a name="output_cognito_hosted_ui_url"></a> [cognito\_hosted\_ui\_url](#output\_cognito\_hosted\_ui\_url) | The URL for the Cognito Hosted UI |
| <a name="output_cognito_identity_pool_arn"></a> [cognito\_identity\_pool\_arn](#output\_cognito\_identity\_pool\_arn) | The ARN of the Cognito Identity Pool |
| <a name="output_cognito_identity_pool_id"></a> [cognito\_identity\_pool\_id](#output\_cognito\_identity\_pool\_id) | The ID of the Cognito Identity Pool |
| <a name="output_cognito_oauth_authorize_endpoint"></a> [cognito\_oauth\_authorize\_endpoint](#output\_cognito\_oauth\_authorize\_endpoint) | The OAuth authorize endpoint URL |
| <a name="output_cognito_oauth_token_endpoint"></a> [cognito\_oauth\_token\_endpoint](#output\_cognito\_oauth\_token\_endpoint) | The OAuth token endpoint URL |
| <a name="output_cognito_orders_resource_server_identifier"></a> [cognito\_orders\_resource\_server\_identifier](#output\_cognito\_orders\_resource\_server\_identifier) | The resource server identifier for Orders API |
| <a name="output_cognito_preventex_m2m_client_id"></a> [cognito\_preventex\_m2m\_client\_id](#output\_cognito\_preventex\_m2m\_client\_id) | The client ID for Preventex M2M application |
| <a name="output_cognito_preventex_m2m_client_secret"></a> [cognito\_preventex\_m2m\_client\_secret](#output\_cognito\_preventex\_m2m\_client\_secret) | The client secret for Preventex M2M application |
| <a name="output_cognito_resource_server_identifier"></a> [cognito\_resource\_server\_identifier](#output\_cognito\_resource\_server\_identifier) | The identifier of the Cognito Resource Server |
| <a name="output_cognito_resource_server_scopes"></a> [cognito\_resource\_server\_scopes](#output\_cognito\_resource\_server\_scopes) | The scopes of the Cognito Resource Server |
| <a name="output_cognito_results_resource_server_identifier"></a> [cognito\_results\_resource\_server\_identifier](#output\_cognito\_results\_resource\_server\_identifier) | The resource server identifier for Results API |
| <a name="output_cognito_sh24_m2m_client_id"></a> [cognito\_sh24\_m2m\_client\_id](#output\_cognito\_sh24\_m2m\_client\_id) | The client ID for SH:24 M2M application |
| <a name="output_cognito_sh24_m2m_client_secret"></a> [cognito\_sh24\_m2m\_client\_secret](#output\_cognito\_sh24\_m2m\_client\_secret) | The client secret for SH:24 M2M application |
| <a name="output_cognito_unauthenticated_role_arn"></a> [cognito\_unauthenticated\_role\_arn](#output\_cognito\_unauthenticated\_role\_arn) | The ARN of the IAM role for unauthenticated Cognito users |
| <a name="output_cognito_user_pool_arn"></a> [cognito\_user\_pool\_arn](#output\_cognito\_user\_pool\_arn) | The ARN of the Cognito User Pool |
| <a name="output_cognito_user_pool_client_id"></a> [cognito\_user\_pool\_client\_id](#output\_cognito\_user\_pool\_client\_id) | The ID of the Cognito User Pool Client |
| <a name="output_cognito_user_pool_client_secret"></a> [cognito\_user\_pool\_client\_secret](#output\_cognito\_user\_pool\_client\_secret) | The client secret of the Cognito User Pool Client |
| <a name="output_cognito_user_pool_domain"></a> [cognito\_user\_pool\_domain](#output\_cognito\_user\_pool\_domain) | The domain of the Cognito User Pool |
| <a name="output_cognito_user_pool_domain_cloudfront_distribution"></a> [cognito\_user\_pool\_domain\_cloudfront\_distribution](#output\_cognito\_user\_pool\_domain\_cloudfront\_distribution) | The CloudFront distribution for the Cognito User Pool domain (for custom domains) |
| <a name="output_cognito_user_pool_endpoint"></a> [cognito\_user\_pool\_endpoint](#output\_cognito\_user\_pool\_endpoint) | The endpoint of the Cognito User Pool |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | The ID of the Cognito User Pool |
| <a name="output_developer_role_arn"></a> [developer\_role\_arn](#output\_developer\_role\_arn) | ARN of the developer deployment role |
| <a name="output_developer_role_name"></a> [developer\_role\_name](#output\_developer\_role\_name) | Name of the developer deployment role |
| <a name="output_kms_key_alias_arn"></a> [kms\_key\_alias\_arn](#output\_kms\_key\_alias\_arn) | ARN of the KMS key alias |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the shared KMS key |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | ID of the shared KMS key |
| <a name="output_shared_config"></a> [shared\_config](#output\_shared\_config) | All shared service configuration for app deployments |
| <a name="output_sns_alerts_topic_arn"></a> [sns\_alerts\_topic\_arn](#output\_sns\_alerts\_topic\_arn) | ARN of the shared alerts SNS topic |
| <a name="output_sqs_events_dlq_arn"></a> [sqs\_events\_dlq\_arn](#output\_sqs\_events\_dlq\_arn) | ARN of the events DLQ |
| <a name="output_sqs_events_dlq_url"></a> [sqs\_events\_dlq\_url](#output\_sqs\_events\_dlq\_url) | URL of the events DLQ |
| <a name="output_sqs_events_queue_arn"></a> [sqs\_events\_queue\_arn](#output\_sqs\_events\_queue\_arn) | ARN of the events SQS queue |
| <a name="output_sqs_events_queue_url"></a> [sqs\_events\_queue\_url](#output\_sqs\_events\_queue\_url) | URL of the events SQS queue |
| <a name="output_sqs_notifications_dlq_arn"></a> [sqs\_notifications\_dlq\_arn](#output\_sqs\_notifications\_dlq\_arn) | ARN of the notifications DLQ |
| <a name="output_sqs_notifications_dlq_url"></a> [sqs\_notifications\_dlq\_url](#output\_sqs\_notifications\_dlq\_url) | URL of the notifications DLQ |
| <a name="output_sqs_notifications_queue_arn"></a> [sqs\_notifications\_queue\_arn](#output\_sqs\_notifications\_queue\_arn) | ARN of the notifications SQS queue |
| <a name="output_sqs_notifications_queue_url"></a> [sqs\_notifications\_queue\_url](#output\_sqs\_notifications\_queue\_url) | URL of the notifications SQS queue |
| <a name="output_sqs_orders_dlq_arn"></a> [sqs\_orders\_dlq\_arn](#output\_sqs\_orders\_dlq\_arn) | ARN of the orders DLQ |
| <a name="output_sqs_orders_dlq_url"></a> [sqs\_orders\_dlq\_url](#output\_sqs\_orders\_dlq\_url) | URL of the orders DLQ |
| <a name="output_sqs_orders_queue_arn"></a> [sqs\_orders\_queue\_arn](#output\_sqs\_orders\_queue\_arn) | ARN of the orders SQS queue |
| <a name="output_sqs_orders_queue_url"></a> [sqs\_orders\_queue\_url](#output\_sqs\_orders\_queue\_url) | URL of the orders SQS queue |
| <a name="output_waf_cloudfront_arn"></a> [waf\_cloudfront\_arn](#output\_waf\_cloudfront\_arn) | ARN of the CloudFront WAF Web ACL (for CloudFront distributions) |
| <a name="output_waf_cloudfront_id"></a> [waf\_cloudfront\_id](#output\_waf\_cloudfront\_id) | ID of the CloudFront WAF Web ACL |
| <a name="output_waf_regional_arn"></a> [waf\_regional\_arn](#output\_waf\_regional\_arn) | ARN of the regional WAF Web ACL (for API Gateway) |
| <a name="output_waf_regional_id"></a> [waf\_regional\_id](#output\_waf\_regional\_id) | ID of the regional WAF Web ACL |
<!-- END_TF_DOCS -->
