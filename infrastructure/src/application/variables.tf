################################################################################
# Variables - Application (Lambda) Module
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

#------------------------------------------------------------------------------
# Lambda Configuration
#------------------------------------------------------------------------------

variable "lambda_name" {
  description = "Name suffix for the Lambda function (will be prefixed with resource_prefix)"
  type        = string
  default     = "api"
}

variable "lambda_description" {
  description = "Description of the Lambda function"
  type        = string
  default     = "API Lambda function"
}

variable "lambda_handler" {
  description = "Lambda function handler (e.g., index.handler)"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "nodejs20.x"

  validation {
    condition = contains([
      "nodejs18.x", "nodejs20.x",
      "python3.9", "python3.10", "python3.11", "python3.12",
      "java17", "java21",
      "dotnet6", "dotnet8",
      "ruby3.2", "ruby3.3",
      "provided.al2", "provided.al2023"
    ], var.lambda_runtime)
    error_message = "Lambda runtime must be a valid AWS Lambda runtime."
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

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory must be between 128 MB and 10240 MB."
  }
}

#------------------------------------------------------------------------------
# Lambda Package - S3 or Local
#------------------------------------------------------------------------------

variable "lambda_s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = ""
}

variable "lambda_s3_key" {
  description = "S3 key of the Lambda deployment package"
  type        = string
  default     = ""
}

variable "lambda_s3_object_version" {
  description = "S3 object version of the Lambda deployment package"
  type        = string
  default     = ""
}

variable "lambda_filename" {
  description = "Path to the local Lambda deployment package (zip file)"
  type        = string
  default     = ""
}

variable "lambda_source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package (for update detection)"
  type        = string
  default     = null
}

variable "code_signing_config_arn" {
  description = "ARN of the code signing configuration for Lambda (optional - for compliance)"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "enable_vpc" {
  description = "Deploy Lambda function in VPC"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs for Lambda"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Environment Variables
#------------------------------------------------------------------------------

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Concurrency and DLQ
#------------------------------------------------------------------------------

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda (-1 for no reservation)"
  type        = number
  default     = -1
}

variable "dead_letter_queue_arn" {
  description = "ARN of the SQS queue or SNS topic for dead letter queue"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Alias Configuration
#------------------------------------------------------------------------------

variable "create_alias" {
  description = "Create a Lambda alias for stable endpoint"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name of the Lambda alias"
  type        = string
  default     = "live"
}

variable "alias_function_version" {
  description = "Lambda function version for the alias (empty for $LATEST)"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Tracing
#------------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for Lambda"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Logging
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Artifacts Bucket
#------------------------------------------------------------------------------

variable "create_artifacts_bucket" {
  description = "Create an S3 bucket for Lambda artifacts"
  type        = bool
  default     = true
}

variable "artifacts_retention_days" {
  description = "Number of days to retain old artifact versions"
  type        = number
  default     = 30
}

#------------------------------------------------------------------------------
# IAM Permissions
#------------------------------------------------------------------------------

variable "additional_iam_statements" {
  description = "Additional IAM policy statements for the Lambda execution role"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

#------------------------------------------------------------------------------
# Alarms
#------------------------------------------------------------------------------

variable "create_alarms" {
  description = "Create CloudWatch alarms for the Lambda function"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "Error count threshold for alarm"
  type        = number
  default     = 5
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when alarm returns to OK"
  type        = list(string)
  default     = []
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
