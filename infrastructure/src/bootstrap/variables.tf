################################################################################
# Variables
################################################################################

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
  description = "Environment name (e.g., mgmt, dev, staging, prod)"
  type        = string
  default     = "mgmt"

  # validation {
  #   condition     = contains(["mgmt", "dev", "staging", "prod"], var.environment)
  #   error_message = "Environment must be one of: mgmt, dev, staging, prod."
  # }
}


variable "github_repo" {
  description = "GitHub repository in format 'owner/repo-name'"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+/[a-zA-Z0-9._-]+$", var.github_repo))
    error_message = "GitHub repo must be in format 'owner/repo-name'."
  }
}

variable "github_branches" {
  description = "List of GitHub branch patterns allowed to assume the OIDC role"
  type        = list(string)
  default     = ["main", "develop"]
}

variable "github_environments" {
  description = "List of GitHub environments allowed to assume the OIDC role"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "github_allow_all_branches" {
  description = "Allow all branches to assume the OIDC role (disables branch restrictions). Use with caution in production."
  type        = bool
  default     = false
}

variable "enable_state_bucket_logging" {
  description = "Enable access logging for the state bucket"
  type        = bool
  default     = true
}

variable "state_bucket_retention_days" {
  description = "Number of days to retain noncurrent versions of state files"
  type        = number
  default     = 90
}

variable "enable_dynamodb_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB lock table"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window_days" {
  description = "Number of days before KMS key is deleted"
  type        = number
  default     = 30
}

variable "additional_iam_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the GitHub Actions role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
