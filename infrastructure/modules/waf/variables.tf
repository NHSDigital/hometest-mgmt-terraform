################################################################################
# WAF Module Variables
################################################################################

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "scope" {
  description = "WAF scope (REGIONAL for API Gateway, CLOUDFRONT for CloudFront)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

# Rule Configuration
variable "common_ruleset_excluded_rules" {
  description = "Rules to exclude from AWS Common Rule Set (set to COUNT instead of BLOCK)"
  type        = list(string)
  default     = []
}

variable "enable_ip_reputation" {
  description = "Enable AWS IP Reputation rule set"
  type        = bool
  default     = true
}

variable "enable_anonymous_ip_list" {
  description = "Enable AWS Anonymous IP List rule set"
  type        = bool
  default     = false
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting rule"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per 5-minute period per IP)"
  type        = number
  default     = 2000
}

variable "blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

variable "ip_allow_list_arn" {
  description = "ARN of IP set for allow list"
  type        = string
  default     = null
}

# Logging Configuration
variable "enable_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = null
}

variable "redacted_fields" {
  description = "Fields to redact from logs"
  type = list(object({
    type = string
    name = string
  }))
  default = [
    { type = "single_header", name = "authorization" },
    { type = "single_header", name = "cookie" }
  ]
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
