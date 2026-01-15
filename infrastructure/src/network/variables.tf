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
    "lambda",           # Lambda service endpoint
    "execute-api",      # API Gateway
    "secretsmanager",   # Secrets Manager
    "ssm",              # Systems Manager
    "ssmmessages",      # SSM Messages
    "ec2messages",      # EC2 Messages
    "logs",             # CloudWatch Logs
    "monitoring",       # CloudWatch Monitoring
    "sqs",              # SQS
    "sns",              # SNS
    "kms",              # KMS
    "sts",              # STS
    "ecr.api",          # ECR API
    "ecr.dkr"           # ECR Docker Registry
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

variable "create_elasticache_sg" {
  description = "Create a security group for ElastiCache"
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
    ip          = string      # IP address or CIDR (e.g., "203.0.113.10/32")
    port        = string      # Port number or "ANY"
    protocol    = string      # Protocol: TCP, UDP, or IP
    description = string      # Description for documentation
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
  default     = "hometest.service.nhs.org"
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
# WAF Configuration
#------------------------------------------------------------------------------

variable "create_waf" {
  description = "Create AWS WAF Web ACL for API Gateway protection"
  type        = bool
  default     = true
}

variable "waf_scope" {
  description = "WAF scope - REGIONAL for API Gateway/ALB, CLOUDFRONT for CloudFront"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.waf_scope)
    error_message = "WAF scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "waf_rate_limit" {
  description = "Maximum requests per 5-minute period per IP before blocking (DDoS protection)"
  type        = number
  default     = 2000
}

variable "waf_logs_retention_days" {
  description = "Number of days to retain WAF logs"
  type        = number
  default     = 90
}

variable "waf_common_rules_excluded" {
  description = "List of AWS managed common rules to set to COUNT instead of BLOCK (for tuning)"
  type        = list(string)
  default     = []
}

variable "waf_block_anonymous_ips" {
  description = "Block requests from VPNs, Tor, proxies, and hosting providers"
  type        = bool
  default     = false
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2). Empty list allows all countries."
  type        = list(string)
  default     = [] # e.g., ["GB", "IE"] for UK and Ireland only

  # Example:
  # waf_allowed_countries = ["GB"] # UK only for NHS services
}

variable "waf_ip_allowlist_enabled" {
  description = "Enable IP allowlist - only allow specific IP addresses"
  type        = bool
  default     = false
}

variable "waf_ip_allowlist" {
  description = "List of IP addresses/CIDRs to allow (when waf_ip_allowlist_enabled is true)"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# ACM Certificate Configuration
#------------------------------------------------------------------------------

variable "create_acm_certificate" {
  description = "Create ACM certificate for the Route 53 domain"
  type        = bool
  default     = true
}

variable "acm_subject_alternative_names" {
  description = "Additional domain names for the ACM certificate"
  type        = list(string)
  default     = []

  # Example:
  # acm_subject_alternative_names = [
  #   "*.hometest.service.nhs.org",  # Wildcard for subdomains
  #   "api.hometest.service.nhs.org"
  # ]
}

#------------------------------------------------------------------------------
# API Gateway Security Configuration
#------------------------------------------------------------------------------

variable "create_api_gateway_sg" {
  description = "Create security group for API Gateway VPC Link"
  type        = bool
  default     = true
}

variable "create_vpc_link" {
  description = "Create VPC Link for private API Gateway integration with Lambda"
  type        = bool
  default     = true
}

variable "api_gateway_allowed_cidrs" {
  description = "CIDR blocks allowed to access API Gateway (for VPC Link)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_api_gateway_resource_policy" {
  description = "Create a resource policy for API Gateway to restrict access"
  type        = bool
  default     = false
}

variable "api_gateway_allowed_ips" {
  description = "List of IP addresses allowed to access API Gateway (for resource policy)"
  type        = list(string)
  default     = []
}

variable "api_gateway_allow_from_vpc" {
  description = "Allow API Gateway access from within the VPC"
  type        = bool
  default     = true
}
