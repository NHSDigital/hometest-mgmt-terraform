################################################################################
# Variables - IAM Developer Role Module
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
  description = "Environment name (e.g., dev, staging, prod) - used for scoping permissions"
  type        = string
}

#------------------------------------------------------------------------------
# Trust Relationship Configuration
#------------------------------------------------------------------------------

variable "enable_sso_trust" {
  description = "Enable trust for AWS SSO / Identity Center users"
  type        = bool
  default     = false
}

variable "allowed_teams" {
  description = "List of team tags allowed to assume this role (for SSO trust)"
  type        = list(string)
  default     = ["developers"]
}

variable "enable_aft_trust" {
  description = "Enable trust for AWS Account Factory for Terraform (AFT)"
  type        = bool
  default     = true
}

variable "aft_management_account_id" {
  description = "AWS Account ID of the AFT management account (for cross-account trust)"
  type        = string
  default     = ""
}

variable "aft_external_id" {
  description = "External ID for AFT role assumption (for security)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_github_oidc_trust" {
  description = "Enable trust for GitHub Actions OIDC"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo-name' for OIDC trust"
  type        = string
  default     = ""
}

variable "enable_account_trust" {
  description = "Enable trust from account root (for testing - not recommended for production)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Session Configuration
#------------------------------------------------------------------------------

variable "max_session_duration" {
  description = "Maximum session duration in seconds (1 hour to 12 hours)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

#------------------------------------------------------------------------------
# Additional Permissions
#------------------------------------------------------------------------------

variable "additional_iam_statements" {
  description = "Additional IAM policy statements to attach to the developer role"
  type = list(object({
    Sid      = string
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
