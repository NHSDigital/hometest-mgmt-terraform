################################################################################
# HomeTest Service Application Variables
################################################################################

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# Encryption
variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = null
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "artifact_retention_days" {
  description = "Days to retain old deployment artifacts"
  type        = number
  default     = 30
}

# Lambda VPC Configuration
variable "enable_vpc_access" {
  description = "Enable VPC access for Lambda functions"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
  default     = null
}

variable "lambda_vpc_subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = null
}

variable "lambda_security_group_ids" {
  description = "Security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = null
}

# Lambda Resource Access
variable "lambda_secrets_arns" {
  description = "Secrets Manager ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "lambda_ssm_parameter_arns" {
  description = "SSM parameter ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "lambda_s3_bucket_arns" {
  description = "S3 bucket ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "lambda_dynamodb_table_arns" {
  description = "DynamoDB table ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "lambda_sqs_queue_arns" {
  description = "SQS queue ARNs for Lambda access"
  type        = list(string)
  default     = []
}

# Lambda Code Hashes (for updates)
variable "eligibility_test_info_hash" {
  description = "Source code hash for eligibility-test-info Lambda"
  type        = string
  default     = null
}

variable "order_router_hash" {
  description = "Source code hash for order-router Lambda"
  type        = string
  default     = null
}

variable "hello_world_hash" {
  description = "Source code hash for hello-world Lambda"
  type        = string
  default     = null
}

# Lambda Environment Variables
variable "eligibility_test_info_env_vars" {
  description = "Additional environment variables for eligibility-test-info Lambda"
  type        = map(string)
  default     = {}
}

variable "order_router_env_vars" {
  description = "Additional environment variables for order-router Lambda"
  type        = map(string)
  default     = {}
}

# API Gateway Configuration
variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "api_endpoint_type" {
  description = "API Gateway endpoint type"
  type        = string
  default     = "REGIONAL"
}

variable "api_throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 5000
}

variable "api_throttling_rate_limit" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 10000
}

variable "api_custom_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = null
}

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for API custom domain"
  type        = string
  default     = null
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "spa_custom_domain_names" {
  description = "Custom domain names for CloudFront SPA"
  type        = list(string)
  default     = []
}

variable "spa_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront custom domains (must be in us-east-1)"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "cloudfront_logging_bucket_domain_name" {
  description = "S3 bucket domain name for CloudFront access logs"
  type        = string
  default     = null
}

# Security Configuration
variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
  default     = null
}

variable "content_security_policy" {
  description = "Content Security Policy header"
  type        = string
  default     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"
}

variable "permissions_policy" {
  description = "Permissions Policy header"
  type        = string
  default     = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
}

variable "geo_restriction_type" {
  description = "Geo restriction type (whitelist, blacklist, none)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

# Developer IAM Configuration
variable "developer_account_arns" {
  description = "IAM ARNs of developers who can assume the deployment role"
  type        = list(string)
  default     = []
}

variable "developer_require_mfa" {
  description = "Require MFA for developer role assumption"
  type        = bool
  default     = true
}

variable "developer_require_external_id" {
  description = "Require external ID for developer role assumption"
  type        = bool
  default     = false
}

variable "developer_external_id" {
  description = "External ID for developer role assumption"
  type        = string
  default     = null
}

variable "developer_allowed_ip_ranges" {
  description = "IP ranges allowed for developer role assumption"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
