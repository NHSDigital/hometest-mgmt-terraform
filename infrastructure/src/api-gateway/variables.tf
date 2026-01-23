################################################################################
# Variables - API Gateway Module
################################################################################

#------------------------------------------------------------------------------
# Required Variables
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID for resources"
  type        = string
}

variable "aws_account_shortname" {
  description = "AWS account short name/alias for resource naming"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to integrate with"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

#------------------------------------------------------------------------------
# mTLS Configuration
#------------------------------------------------------------------------------

variable "enable_mtls" {
  description = "Enable mTLS (mutual TLS) authentication for API Gateway"
  type        = bool
  default     = true
}

variable "truststore_content" {
  description = "Content of the truststore PEM file (CA certificates for client validation)"
  type        = string
  default     = ""
  sensitive   = true
}

#------------------------------------------------------------------------------
# Custom Domain Configuration
#------------------------------------------------------------------------------

variable "create_custom_domain" {
  description = "Create a custom domain for the API Gateway"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Custom domain name for the API Gateway (e.g., dev.hometest.service.nhs.uk)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 Zone ID for creating DNS alias record to API Gateway"
  type        = string
  default     = ""
}

variable "create_dns_record" {
  description = "Create Route53 A record alias for the custom domain"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Stage Configuration
#------------------------------------------------------------------------------

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

#------------------------------------------------------------------------------
# Authorization
#------------------------------------------------------------------------------

variable "authorization_type" {
  description = "Authorization type for API Gateway methods (NONE, AWS_IAM, CUSTOM, COGNITO_USER_POOLS)"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "AWS_IAM", "CUSTOM", "COGNITO_USER_POOLS"], var.authorization_type)
    error_message = "Authorization type must be one of: NONE, AWS_IAM, CUSTOM, COGNITO_USER_POOLS."
  }
}

#------------------------------------------------------------------------------
# Logging Configuration
#------------------------------------------------------------------------------

variable "logging_level" {
  description = "Logging level for API Gateway (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["OFF", "ERROR", "INFO"], var.logging_level)
    error_message = "Logging level must be one of: OFF, ERROR, INFO."
  }
}

variable "data_trace_enabled" {
  description = "Enable full request/response data tracing (use with caution - may log sensitive data)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Throttling Configuration
#------------------------------------------------------------------------------

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 10000
}

#------------------------------------------------------------------------------
# Features
#------------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "enable_compression" {
  description = "Enable response compression"
  type        = bool
  default     = true
}

variable "minimum_compression_size" {
  description = "Minimum response size to compress (in bytes)"
  type        = number
  default     = 1024
}

#------------------------------------------------------------------------------
# KMS Configuration
#------------------------------------------------------------------------------

variable "kms_key_deletion_window_days" {
  description = "Number of days before KMS key is deleted"
  type        = number
  default     = 30
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
