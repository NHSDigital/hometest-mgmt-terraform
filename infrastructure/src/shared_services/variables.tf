################################################################################
# Shared Services Variables
################################################################################

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (core for shared services)"
  type        = string
  default     = "core"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# KMS Configuration
################################################################################

variable "kms_deletion_window_days" {
  description = "Number of days before KMS key is deleted"
  type        = number
  default     = 30
}

################################################################################
# WAF Configuration
################################################################################

variable "waf_rate_limit" {
  description = "Rate limit for WAF (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "waf_log_retention_days" {
  description = "Days to retain WAF logs"
  type        = number
  default     = 30
}

################################################################################
# ACM Configuration
################################################################################

variable "create_acm_certificates" {
  description = "Whether to create ACM certificates"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Base domain name for certificates (e.g., dev.hometest.service.nhs.uk)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 zone ID for DNS validation"
  type        = string
}

################################################################################
# Deployment Artifacts
################################################################################

variable "artifact_retention_days" {
  description = "Days to retain old artifact versions"
  type        = number
  default     = 30
}

################################################################################
# Developer IAM
################################################################################

variable "developer_account_arns" {
  description = "List of AWS account ARNs allowed to assume the developer role"
  type        = list(string)
  default     = []
}

variable "require_mfa" {
  description = "Require MFA for developer role assumption"
  type        = bool
  default     = true
}
