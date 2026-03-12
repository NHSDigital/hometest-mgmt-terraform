################################################################################
# Deployment Artifacts Module Variables
################################################################################

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = null
}

variable "artifact_retention_days" {
  description = "Days to retain old artifact versions"
  type        = number
  default     = 30
}

variable "enable_intelligent_tiering" {
  description = "Enable intelligent tiering for cost optimization"
  type        = bool
  default     = false
}

variable "logging_bucket_id" {
  description = "S3 bucket ID for access logging"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
