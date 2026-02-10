################################################################################
# Developer IAM Module Variables
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

variable "developer_account_arns" {
  description = "List of IAM ARNs (users, roles, or root accounts) that can assume this role"
  type        = list(string)

  validation {
    condition     = length(var.developer_account_arns) > 0
    error_message = "At least one developer account ARN must be provided."
  }
}

# Role Configuration
variable "max_session_duration" {
  description = "Maximum session duration in seconds (1-12 hours)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

# Security Configuration
variable "require_mfa" {
  description = "Require MFA for role assumption"
  type        = bool
  default     = true
}

variable "require_external_id" {
  description = "Require external ID for role assumption (confused deputy protection)"
  type        = bool
  default     = false
}

variable "external_id" {
  description = "External ID for role assumption"
  type        = string
  default     = null
}

variable "allowed_ip_ranges" {
  description = "List of IP CIDR ranges allowed to assume the role"
  type        = list(string)
  default     = []
}

# Resource References
variable "cloudfront_distribution_arn" {
  description = "ARN of CloudFront distribution (optional, allows all if not specified)"
  type        = string
  default     = null
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption/decryption"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
