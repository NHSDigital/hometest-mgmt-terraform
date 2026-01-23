################################################################################
# Variables - DNS Certificate Module
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
# Domain Configuration
#------------------------------------------------------------------------------

variable "base_domain_name" {
  description = "Base domain name (e.g., hometest.service.nhs.uk)"
  type        = string
  default     = "hometest.service.nhs.uk"
}

variable "additional_domain_names" {
  description = "Additional domain names (SANs) for the certificate"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# API Gateway Integration
#------------------------------------------------------------------------------

variable "create_api_gateway_record" {
  description = "Create Route53 A record alias to API Gateway"
  type        = bool
  default     = false
}

variable "api_gateway_regional_domain_name" {
  description = "Regional domain name of the API Gateway custom domain"
  type        = string
  default     = ""
}

variable "api_gateway_regional_zone_id" {
  description = "Regional zone ID of the API Gateway custom domain"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Health Check Configuration
#------------------------------------------------------------------------------

variable "create_health_check" {
  description = "Create Route53 health check for the endpoint"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path for the health check"
  type        = string
  default     = "/health"
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive failures before unhealthy"
  type        = number
  default     = 3
}

variable "health_check_request_interval" {
  description = "Seconds between health checks (10 or 30)"
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.health_check_request_interval)
    error_message = "Health check interval must be 10 or 30 seconds."
  }
}

#------------------------------------------------------------------------------
# Alarms
#------------------------------------------------------------------------------

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
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
