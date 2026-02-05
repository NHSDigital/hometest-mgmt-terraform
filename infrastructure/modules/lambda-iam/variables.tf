################################################################################
# Lambda IAM Module Variables
################################################################################

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Role Configuration
variable "max_session_duration" {
  description = "Maximum session duration in seconds"
  type        = number
  default     = 3600
}

variable "restrict_to_account" {
  description = "Restrict role assumption to specific account"
  type        = bool
  default     = true
}

# Feature Toggles
variable "enable_xray" {
  description = "Enable X-Ray tracing permissions"
  type        = bool
  default     = true
}

variable "enable_vpc_access" {
  description = "Enable VPC access permissions"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for VPC access condition"
  type        = string
  default     = null
}

# Resource ARNs for access policies
variable "secrets_arns" {
  description = "List of Secrets Manager secret ARNs to access"
  type        = list(string)
  default     = []
}

variable "ssm_parameter_arns" {
  description = "List of SSM parameter ARNs to access"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for decryption"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for access"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs for access"
  type        = list(string)
  default     = []
}

variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs for access"
  type        = list(string)
  default     = []
}

# Custom Policies
variable "custom_policies" {
  description = "Map of custom policy names to policy JSON documents"
  type        = map(string)
  default     = {}
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
