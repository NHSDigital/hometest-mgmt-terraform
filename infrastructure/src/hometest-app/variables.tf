################################################################################
# HomeTest Service Application Variables
################################################################################

#------------------------------------------------------------------------------
# Project Configuration
#------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, dev1, dev2, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Dependencies from shared_services
#------------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of shared KMS key (from shared_services)"
  type        = string
}

variable "waf_regional_arn" {
  description = "ARN of regional WAF Web ACL for API Gateway (from shared_services)"
  type        = string
  default     = null
}

variable "waf_cloudfront_arn" {
  description = "ARN of CloudFront WAF Web ACL (from shared_services)"
  type        = string
  default     = null
}

variable "deployment_bucket_id" {
  description = "ID of shared deployment artifacts bucket (from shared_services)"
  type        = string
}

variable "deployment_bucket_arn" {
  description = "ARN of shared deployment artifacts bucket (from shared_services)"
  type        = string
}

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for API custom domains (from shared_services)"
  type        = string
  default     = null
}

variable "spa_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (us-east-1, from shared_services)"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Dependencies from network
#------------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID (from network)"
  type        = string
  default     = null
}

variable "lambda_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC configuration (from network)"
  type        = list(string)
  default     = []
}

variable "lambda_security_group_ids" {
  description = "Security group IDs for Lambda (from network)"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (from network)"
  type        = string
}

#------------------------------------------------------------------------------
# Lambda Configuration
#------------------------------------------------------------------------------

variable "enable_vpc_access" {
  description = "Enable VPC access for Lambda functions"
  type        = bool
  default     = false
}

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
  default     = 14
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
  description = "Additional S3 bucket ARNs for Lambda access"
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

# Lambda Code Hashes
variable "api1_lambda_hash" {
  description = "Source code hash for API 1 Lambda"
  type        = string
  default     = null
}

variable "api2_lambda_hash" {
  description = "Source code hash for API 2 Lambda"
  type        = string
  default     = null
}

# Lambda Environment Variables
variable "api1_env_vars" {
  description = "Additional environment variables for API 1 Lambda"
  type        = map(string)
  default     = {}
}

variable "api2_env_vars" {
  description = "Additional environment variables for API 2 Lambda"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# API Gateway Configuration
#------------------------------------------------------------------------------

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
  default     = 1000
}

variable "api_throttling_rate_limit" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 2000
}

# API Gateway Custom Domains
variable "api1_custom_domain_name" {
  description = "Custom domain name for API 1 (e.g., api1.dev1.hometest.service.nhs.uk)"
  type        = string
  default     = null
}

variable "api2_custom_domain_name" {
  description = "Custom domain name for API 2 (e.g., api2.dev1.hometest.service.nhs.uk)"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# CloudFront Configuration
#------------------------------------------------------------------------------

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

#------------------------------------------------------------------------------
# Security Configuration
#------------------------------------------------------------------------------

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
