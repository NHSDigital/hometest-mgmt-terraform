################################################################################
# CloudFront SPA Module Variables
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

variable "aws_account_shortname" {
  description = "AWS account short name/alias for resource naming"
  type        = string
}

# S3 Configuration
variable "s3_kms_key_arn" {
  description = "ARN of KMS key for S3 bucket encryption"
  type        = string
  default     = null
}

variable "s3_noncurrent_version_expiration_days" {
  description = "Days before noncurrent versions are deleted"
  type        = number
  default     = 30
}

# CloudFront Configuration
variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "Price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "enable_spa_routing" {
  description = "Enable CloudFront function for SPA routing"
  type        = bool
  default     = true
}

# Custom Domain Configuration
variable "custom_domain_names" {
  description = "List of custom domain names for CloudFront"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domains (must be in us-east-1)"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
  default     = null
}

# API Gateway Integration (supports multiple APIs with path-based routing)
variable "api_origins" {
  description = "Map of API origins for path-based routing. Key is the path prefix (e.g., 'api1'), value contains domain_name and optional origin_path"
  type = map(object({
    domain_name = string
    origin_path = optional(string, "")
  }))
  default = {}
}

# Legacy single API Gateway Integration (deprecated, use api_origins instead)
variable "api_gateway_domain_name" {
  description = "DEPRECATED: Use api_origins instead. Domain name of the API Gateway"
  type        = string
  default     = null
}

variable "api_gateway_origin_path" {
  description = "DEPRECATED: Use api_origins instead. Origin path for API Gateway"
  type        = string
  default     = ""
}

# Security Configuration
variable "waf_web_acl_arn" {
  description = "ARN of WAF Web ACL to associate with CloudFront"
  type        = string
  default     = null
}

variable "content_security_policy" {
  description = "Content Security Policy header value"
  type        = string
  default     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"
}

variable "permissions_policy" {
  description = "Permissions Policy header value"
  type        = string
  default     = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
}

# Geo Restriction
variable "geo_restriction_type" {
  description = "Geo restriction type (whitelist, blacklist, none)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["whitelist", "blacklist", "none"], var.geo_restriction_type)
    error_message = "Geo restriction type must be whitelist, blacklist, or none."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

# Logging Configuration
variable "enable_access_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "logging_bucket_domain_name" {
  description = "S3 bucket domain name for CloudFront access logs"
  type        = string
  default     = null
}

variable "s3_access_log_retention_days" {
  description = "Number of days to retain S3 server access logs before expiry"
  type        = number
  default     = 90
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
