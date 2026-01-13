################################################################################
# Variables for Lambda Web App Deployment
################################################################################

#------------------------------------------------------------------------------
# AWS Configuration
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

#------------------------------------------------------------------------------
# Project Configuration
#------------------------------------------------------------------------------

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

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "account_name" {
  description = "AWS account name/alias for resource naming"
  type        = string
}

#------------------------------------------------------------------------------
# Lambda Configuration
#------------------------------------------------------------------------------

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 512

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda (-1 for no limit)"
  type        = number
  default     = -1
}

variable "lambda_architecture" {
  description = "Lambda architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Lambda architecture must be x86_64 or arm64."
  }
}

#------------------------------------------------------------------------------
# Container Configuration
#------------------------------------------------------------------------------

variable "container_image_uri" {
  description = "ECR image URI for the Lambda container (leave empty to use placeholder)"
  type        = string
  default     = ""
}

variable "container_command" {
  description = "Container command override"
  type        = list(string)
  default     = []
}

variable "container_entry_point" {
  description = "Container entry point override"
  type        = list(string)
  default     = []
}

variable "container_working_directory" {
  description = "Container working directory"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Application Configuration
#------------------------------------------------------------------------------

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "webapp"
}

variable "app_port" {
  description = "Application port (used for health checks and documentation)"
  type        = number
  default     = 8080
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "secrets_arns" {
  description = "ARNs of Secrets Manager secrets the Lambda can access"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# API Gateway Configuration
#------------------------------------------------------------------------------

variable "enable_api_gateway" {
  description = "Enable API Gateway HTTP API for the Lambda"
  type        = bool
  default     = true
}

variable "api_gateway_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "$default"
}

variable "enable_api_gateway_access_logs" {
  description = "Enable API Gateway access logging"
  type        = bool
  default     = true
}

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 50
}

#------------------------------------------------------------------------------
# Lambda Function URL Configuration (Alternative to API Gateway)
#------------------------------------------------------------------------------

variable "enable_function_url" {
  description = "Enable Lambda Function URL (alternative to API Gateway)"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Lambda Function URL auth type (NONE or AWS_IAM)"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.function_url_auth_type)
    error_message = "Function URL auth type must be NONE or AWS_IAM."
  }
}

variable "function_url_cors" {
  description = "CORS configuration for Lambda Function URL"
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), ["*"])
    allow_methods     = optional(list(string), ["*"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 86400)
  })
  default = {}
}

#------------------------------------------------------------------------------
# VPC Configuration (Optional)
#------------------------------------------------------------------------------

variable "vpc_enabled" {
  description = "Deploy Lambda in VPC"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "VPC subnet IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs for Lambda"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Observability Configuration
#------------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Lambda"
  type        = bool
  default     = true
}

variable "alarm_error_threshold" {
  description = "Error count threshold for CloudWatch alarm"
  type        = number
  default     = 5
}

variable "alarm_duration_threshold" {
  description = "Duration threshold in ms for CloudWatch alarm"
  type        = number
  default     = 5000
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
