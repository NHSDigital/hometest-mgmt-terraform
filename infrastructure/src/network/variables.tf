################################################################################
# Variables - Network Module
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
  description = "Environment name (e.g., mgmt, dev, staging, prod)"
  type        = string

  # validation {
  #   condition     = contains(["mgmt", "dev", "staging", "prod"], var.environment)
  #   error_message = "Environment must be one of: mgmt, dev, staging, prod."
  # }
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Recommended /16 for full subnet allocation."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use (2-3 recommended for high availability)"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "AZ count must be between 2 and 3 for high availability."
  }
}

variable "enable_ipv6" {
  description = "Enable IPv6 CIDR block assignment for the VPC (dual-stack)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# NAT Gateway Configuration
#------------------------------------------------------------------------------

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all AZs (cost savings, but less HA). Set to false for production."
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# VPC Flow Logs Configuration
#------------------------------------------------------------------------------

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_logs_retention_days)
    error_message = "Flow logs retention must be a valid CloudWatch Logs retention period."
  }
}

#------------------------------------------------------------------------------
# VPC Endpoints Configuration
#------------------------------------------------------------------------------

variable "enable_interface_endpoints" {
  description = "Enable VPC Interface Endpoints for AWS services (incurs costs)"
  type        = bool
  default     = true
}

variable "interface_endpoints" {
  description = "List of AWS services to create Interface VPC Endpoints for"
  type        = list(string)
  default = [
    "lambda",         # Lambda service endpoint
    "execute-api",    # API Gateway
    "secretsmanager", # Secrets Manager
    # "ssm",              # Systems Manager
    # "ssmmessages",      # SSM Messages
    # "ec2messages",      # EC2 Messages
    "logs",       # CloudWatch Logs
    "monitoring", # CloudWatch Monitoring
    "sqs",        # SQS
    # "sns",              # SNS
    "kms",     # KMS
    "sts",     # STS, IAM
    "ecr.api", # ECR API
    "ecr.dkr"  # ECR Docker Registry
  ]
}

#------------------------------------------------------------------------------
# Security Group Flags
#------------------------------------------------------------------------------

variable "create_db_subnet_group" {
  description = "Create a DB subnet group for RDS"
  type        = bool
  default     = true
}

variable "create_lambda_rds_sg" {
  description = "Create a dedicated security group for Lambda to RDS access"
  type        = bool
  default     = true
}

variable "create_rds_sg" {
  description = "Create a security group for RDS databases"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Network Firewall & Egress Filtering
#------------------------------------------------------------------------------

variable "enable_network_firewall" {
  description = "Enable AWS Network Firewall for egress filtering and deep packet inspection"
  type        = bool
  default     = false
}

variable "firewall_logs_retention_days" {
  description = "Number of days to retain Network Firewall logs in CloudWatch"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.firewall_logs_retention_days)
    error_message = "Firewall logs retention must be a valid CloudWatch Logs retention period."
  }
}

variable "firewall_default_deny" {
  description = "Enable default deny rule - drops all traffic not explicitly allowed. CAUTION: Ensure all required destinations are in allowed lists before enabling."
  type        = bool
  default     = true
}

variable "allowed_egress_ips" {
  description = "List of allowed egress IP addresses with port and protocol. These IPs will be permitted through the firewall."
  type = list(object({
    ip          = string # IP address or CIDR (e.g., "203.0.113.10/32")
    port        = string # Port number or "ANY"
    protocol    = string # Protocol: TCP, UDP, or IP
    description = string # Description for documentation
  }))
  default = []

  # Example:
  # allowed_egress_ips = [
  #   {
  #     ip          = "203.0.113.10/32"
  #     port        = "443"
  #     protocol    = "TCP"
  #     description = "External API server"
  #   },
  #   {
  #     ip          = "198.51.100.0/24"
  #     port        = "ANY"
  #     protocol    = "TCP"
  #     description = "Partner network"
  #   }
  # ]
}

variable "allowed_egress_domains" {
  description = "List of allowed egress domains (for HTTPS/TLS traffic). Supports wildcards like '.example.com'."
  type        = list(string)
  default     = []

  # Example:
  # allowed_egress_domains = [
  #   ".github.com",
  #   ".githubusercontent.com",
  #   "api.stripe.com",
  #   ".nhs.uk",
  #   ".gov.uk"
  # ]
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Route 53 Configuration
#------------------------------------------------------------------------------

variable "route53_zone_name" {
  description = "The domain name for the Route 53 hosted zone"
  type        = string
  default     = "hometest.service.nhs.uk"
}

variable "create_private_hosted_zone" {
  description = "Create a private hosted zone associated with the VPC for internal DNS resolution"
  type        = bool
  default     = false
}

variable "private_zone_name" {
  description = "The domain name for the private hosted zone (defaults to route53_zone_name if not specified)"
  type        = string
  default     = ""
}

variable "enable_dnssec" {
  description = "Enable DNSSEC signing for the hosted zone (recommended for security)"
  type        = bool
  default     = false
}

variable "create_health_check" {
  description = "Create a Route 53 health check for the domain"
  type        = bool
  default     = false
}

variable "health_check_fqdn" {
  description = "The FQDN to health check (defaults to route53_zone_name if not specified)"
  type        = string
  default     = ""
}

variable "health_check_port" {
  description = "The port for the health check"
  type        = number
  default     = 443
}

variable "health_check_type" {
  description = "The type of health check (HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, TCP)"
  type        = string
  default     = "HTTPS"

  validation {
    condition     = contains(["HTTP", "HTTPS", "HTTP_STR_MATCH", "HTTPS_STR_MATCH", "TCP"], var.health_check_type)
    error_message = "Health check type must be one of: HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, TCP."
  }
}

variable "health_check_path" {
  description = "The path for HTTP/HTTPS health checks"
  type        = string
  default     = "/health"
}

variable "health_check_failure_threshold" {
  description = "The number of consecutive health check failures required before considering the endpoint unhealthy"
  type        = number
  default     = 3
}

variable "health_check_request_interval" {
  description = "The number of seconds between health checks (10 or 30)"
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.health_check_request_interval)
    error_message = "Health check request interval must be 10 or 30 seconds."
  }
}

#------------------------------------------------------------------------------
# DNS Query Logging Configuration
#------------------------------------------------------------------------------

variable "enable_dns_query_logging" {
  description = "Enable DNS query logging for Route 53 with near real-time delivery to S3"
  type        = bool
  default     = true
}

variable "dns_query_logs_retention_days" {
  description = "Number of days to retain DNS query logs in S3 before expiration"
  type        = number
  default     = 90
}

variable "dns_query_logs_cloudwatch_retention_days" {
  description = "Number of days to retain DNS query logs in CloudWatch (before S3 delivery)"
  type        = number
  default     = 7
}

variable "dns_query_logs_buffer_size" {
  description = "Buffer size in MB for Kinesis Firehose (1-128 MB). Smaller = more real-time"
  type        = number
  default     = 5

  validation {
    condition     = var.dns_query_logs_buffer_size >= 1 && var.dns_query_logs_buffer_size <= 128
    error_message = "Buffer size must be between 1 and 128 MB."
  }
}

variable "dns_query_logs_buffer_interval" {
  description = "Buffer interval in seconds for Kinesis Firehose (60-900 seconds). Smaller = more real-time"
  type        = number
  default     = 60

  validation {
    condition     = var.dns_query_logs_buffer_interval >= 60 && var.dns_query_logs_buffer_interval <= 900
    error_message = "Buffer interval must be between 60 and 900 seconds."
  }
}

#------------------------------------------------------------------------------
# Cognito User Pool Configuration
#------------------------------------------------------------------------------

variable "enable_cognito" {
  description = "Enable AWS Cognito User Pool for authentication"
  type        = bool
  default     = false
}

variable "cognito_allow_admin_create_user_only" {
  description = "Only allow administrators to create users (disable self-registration)"
  type        = bool
  default     = false
}

variable "cognito_invite_email_subject" {
  description = "Email subject for user invitation emails"
  type        = string
  default     = "Your temporary password"
}

variable "cognito_invite_email_message" {
  description = "Email message for user invitation emails. Must contain {username} and {####} placeholders."
  type        = string
  default     = "Your username is {username} and temporary password is {####}."
}

variable "cognito_invite_sms_message" {
  description = "SMS message for user invitation. Must contain {username} and {####} placeholders."
  type        = string
  default     = "Your username is {username} and temporary password is {####}."
}

variable "cognito_auto_verified_attributes" {
  description = "Attributes to be auto-verified (email, phone_number, or both)"
  type        = list(string)
  default     = ["email"]

  validation {
    condition     = alltrue([for attr in var.cognito_auto_verified_attributes : contains(["email", "phone_number"], attr)])
    error_message = "Auto-verified attributes must be 'email', 'phone_number', or both."
  }
}

variable "cognito_deletion_protection" {
  description = "Enable deletion protection for the user pool"
  type        = bool
  default     = true
}

variable "cognito_device_challenge_required" {
  description = "Require device challenge on new devices"
  type        = bool
  default     = true
}

variable "cognito_device_remember_on_prompt" {
  description = "Only remember devices when user opts in"
  type        = bool
  default     = true
}

variable "cognito_email_sending_account" {
  description = "Email sending account type (COGNITO_DEFAULT or DEVELOPER)"
  type        = string
  default     = "COGNITO_DEFAULT"

  validation {
    condition     = contains(["COGNITO_DEFAULT", "DEVELOPER"], var.cognito_email_sending_account)
    error_message = "Email sending account must be COGNITO_DEFAULT or DEVELOPER."
  }
}

variable "cognito_ses_email_identity_arn" {
  description = "ARN of SES verified email identity (required if email_sending_account is DEVELOPER)"
  type        = string
  default     = null
}

variable "cognito_from_email_address" {
  description = "From email address for Cognito emails (requires DEVELOPER email sending account)"
  type        = string
  default     = null
}

variable "cognito_mfa_configuration" {
  description = "MFA configuration (OFF, ON, OPTIONAL)"
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.cognito_mfa_configuration)
    error_message = "MFA configuration must be OFF, ON, or OPTIONAL."
  }
}

variable "cognito_password_minimum_length" {
  description = "Minimum password length"
  type        = number
  default     = 12

  validation {
    condition     = var.cognito_password_minimum_length >= 8 && var.cognito_password_minimum_length <= 256
    error_message = "Password minimum length must be between 8 and 256."
  }
}

variable "cognito_password_require_lowercase" {
  description = "Require lowercase letters in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_numbers" {
  description = "Require numbers in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_symbols" {
  description = "Require symbols in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_uppercase" {
  description = "Require uppercase letters in password"
  type        = bool
  default     = true
}

variable "cognito_temporary_password_validity_days" {
  description = "Number of days temporary passwords are valid"
  type        = number
  default     = 7
}

variable "cognito_custom_attributes" {
  description = "List of custom user attributes"
  type = list(object({
    name                     = string
    attribute_data_type      = string # String, Number, DateTime, Boolean
    developer_only_attribute = optional(bool, false)
    mutable                  = optional(bool, true)
    required                 = optional(bool, false)
    min_length               = optional(number, 0)
    max_length               = optional(number, 2048)
    min_value                = optional(number)
    max_value                = optional(number)
  }))
  default = []
}

variable "cognito_username_case_sensitive" {
  description = "Whether usernames are case sensitive"
  type        = bool
  default     = false
}

variable "cognito_attributes_require_verification" {
  description = "Attributes that require verification before update"
  type        = list(string)
  default     = ["email"]
}

variable "cognito_verification_email_option" {
  description = "Verification email option (CONFIRM_WITH_LINK or CONFIRM_WITH_CODE)"
  type        = string
  default     = "CONFIRM_WITH_CODE"

  validation {
    condition     = contains(["CONFIRM_WITH_LINK", "CONFIRM_WITH_CODE"], var.cognito_verification_email_option)
    error_message = "Verification email option must be CONFIRM_WITH_LINK or CONFIRM_WITH_CODE."
  }
}

variable "cognito_verification_email_subject" {
  description = "Email subject for verification emails"
  type        = string
  default     = "Your verification code"
}

variable "cognito_verification_email_message" {
  description = "Email message for verification emails. Must contain {####} placeholder."
  type        = string
  default     = "Your verification code is {####}."
}

variable "cognito_verification_email_subject_by_link" {
  description = "Email subject for verification link emails"
  type        = string
  default     = "Verify your email"
}

variable "cognito_verification_email_message_by_link" {
  description = "Email message for verification link emails. Must contain {##Verify Email##} placeholder."
  type        = string
  default     = "Please click the link below to verify your email address. {##Verify Email##}"
}

#------------------------------------------------------------------------------
# Cognito User Pool Domain Configuration
#------------------------------------------------------------------------------

variable "cognito_custom_domain" {
  description = "Custom domain for Cognito hosted UI (leave empty for default AWS domain)"
  type        = string
  default     = ""
}

variable "cognito_domain_certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if using custom domain)"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Cognito User Pool Client Configuration
#------------------------------------------------------------------------------

variable "cognito_access_token_validity" {
  description = "Access token validity in time units"
  type        = number
  default     = 60
}

variable "cognito_id_token_validity" {
  description = "ID token validity in time units"
  type        = number
  default     = 60
}

variable "cognito_refresh_token_validity" {
  description = "Refresh token validity in time units"
  type        = number
  default     = 30
}

variable "cognito_access_token_validity_units" {
  description = "Time unit for access token validity (seconds, minutes, hours, days)"
  type        = string
  default     = "minutes"

  validation {
    condition     = contains(["seconds", "minutes", "hours", "days"], var.cognito_access_token_validity_units)
    error_message = "Token validity unit must be seconds, minutes, hours, or days."
  }
}

variable "cognito_id_token_validity_units" {
  description = "Time unit for ID token validity (seconds, minutes, hours, days)"
  type        = string
  default     = "minutes"

  validation {
    condition     = contains(["seconds", "minutes", "hours", "days"], var.cognito_id_token_validity_units)
    error_message = "Token validity unit must be seconds, minutes, hours, or days."
  }
}

variable "cognito_refresh_token_validity_units" {
  description = "Time unit for refresh token validity (seconds, minutes, hours, days)"
  type        = string
  default     = "days"

  validation {
    condition     = contains(["seconds", "minutes", "hours", "days"], var.cognito_refresh_token_validity_units)
    error_message = "Token validity unit must be seconds, minutes, hours, or days."
  }
}

variable "cognito_allowed_oauth_flows" {
  description = "Allowed OAuth flows (code, implicit, client_credentials)"
  type        = list(string)
  default     = ["code"]

  validation {
    condition     = alltrue([for flow in var.cognito_allowed_oauth_flows : contains(["code", "implicit", "client_credentials"], flow)])
    error_message = "OAuth flows must be code, implicit, or client_credentials."
  }
}

variable "cognito_allowed_oauth_flows_user_pool_client" {
  description = "Whether OAuth flows are allowed for the user pool client"
  type        = bool
  default     = true
}

variable "cognito_allowed_oauth_scopes" {
  description = "Allowed OAuth scopes"
  type        = list(string)
  default     = ["email", "openid", "profile"]
}

variable "cognito_callback_urls" {
  description = "List of allowed callback URLs for OAuth"
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls" {
  description = "List of allowed logout URLs"
  type        = list(string)
  default     = []
}

variable "cognito_supported_identity_providers" {
  description = "Supported identity providers (COGNITO, Facebook, Google, etc.)"
  type        = list(string)
  default     = ["COGNITO"]
}

variable "cognito_generate_client_secret" {
  description = "Generate a client secret for the app client"
  type        = bool
  default     = true
}

variable "cognito_prevent_user_existence_errors" {
  description = "How to handle user existence errors (LEGACY or ENABLED)"
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["LEGACY", "ENABLED"], var.cognito_prevent_user_existence_errors)
    error_message = "Prevent user existence errors must be LEGACY or ENABLED."
  }
}

variable "cognito_enable_token_revocation" {
  description = "Enable token revocation"
  type        = bool
  default     = true
}

variable "cognito_enable_propagate_user_context" {
  description = "Enable propagation of additional user context data"
  type        = bool
  default     = false
}

variable "cognito_explicit_auth_flows" {
  description = "Explicit authentication flows enabled"
  type        = list(string)
  default = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

variable "cognito_read_attributes" {
  description = "List of user pool attributes the app client can read"
  type        = list(string)
  default     = ["email", "email_verified", "name"]
}

variable "cognito_write_attributes" {
  description = "List of user pool attributes the app client can write"
  type        = list(string)
  default     = ["email", "name"]
}

#------------------------------------------------------------------------------
# Cognito Resource Server Configuration
#------------------------------------------------------------------------------

variable "cognito_resource_server_identifier" {
  description = "Identifier for the resource server (defaults to route53_zone_name)"
  type        = string
  default     = ""
}

variable "cognito_resource_server_scopes" {
  description = "List of scopes for the resource server"
  type = list(object({
    name        = string
    description = string
  }))
  default = []
}

#------------------------------------------------------------------------------
# Cognito Identity Pool Configuration
#------------------------------------------------------------------------------

variable "enable_cognito_identity_pool" {
  description = "Enable Cognito Identity Pool for federated identities"
  type        = bool
  default     = false
}

variable "cognito_allow_unauthenticated_identities" {
  description = "Allow unauthenticated identities in the identity pool"
  type        = bool
  default     = false
}

variable "cognito_allow_classic_flow" {
  description = "Allow classic (basic) authentication flow"
  type        = bool
  default     = false
}

variable "cognito_server_side_token_check" {
  description = "Enable server-side token validation"
  type        = bool
  default     = true
}
