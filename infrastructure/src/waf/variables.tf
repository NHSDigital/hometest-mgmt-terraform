################################################################################
# Variables - WAF Module
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
# API Gateway Association
#------------------------------------------------------------------------------

variable "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage to associate with WAF"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Rule Configuration
#------------------------------------------------------------------------------

variable "common_rules_excluded" {
  description = "List of rules from AWSManagedRulesCommonRuleSet to exclude (set to count mode)"
  type        = list(string)
  default     = []
}

variable "enable_linux_rules" {
  description = "Enable AWS Managed Rules for Linux OS"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Rate Limiting
#------------------------------------------------------------------------------

variable "enable_rate_limiting" {
  description = "Enable rate limiting rule"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Maximum number of requests per 5-minute period per IP"
  type        = number
  default     = 2000
}

#------------------------------------------------------------------------------
# IP Filtering
#------------------------------------------------------------------------------

variable "enable_ip_allowlist" {
  description = "Enable IP allowlist rule"
  type        = bool
  default     = false
}

variable "allowed_ip_addresses" {
  description = "List of allowed IP addresses in CIDR notation (e.g., 203.0.113.0/32)"
  type        = list(string)
  default     = []
}

variable "enable_ip_blocklist" {
  description = "Enable IP blocklist rule"
  type        = bool
  default     = false
}

variable "blocked_ip_addresses" {
  description = "List of blocked IP addresses in CIDR notation (e.g., 203.0.113.0/32)"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Geo Restriction
#------------------------------------------------------------------------------

variable "enable_geo_restriction" {
  description = "Enable geographic restriction (block all countries except allowed)"
  type        = bool
  default     = false
}

variable "allowed_countries" {
  description = "List of country codes to allow (ISO 3166-1 alpha-2, e.g., GB, US)"
  type        = list(string)
  default     = ["GB"]
}

#------------------------------------------------------------------------------
# Logging Configuration
#------------------------------------------------------------------------------

variable "log_all_requests" {
  description = "Log all requests (true) or only blocked/counted requests (false)"
  type        = bool
  default     = false
}

variable "redacted_fields" {
  description = "List of fields to redact in WAF logs"
  type = list(object({
    type = string
    name = string
  }))
  default = [
    {
      type = "single_header"
      name = "authorization"
    },
    {
      type = "single_header"
      name = "cookie"
    }
  ]
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
