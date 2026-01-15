################################################################################
# AWS Configuration
################################################################################

variable "aws_account_shortname" {
  description = "AWS account short name/alias for resource naming"
  type        = string
}

################################################################################
# Project Configuration
################################################################################

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

################################################################################
# Network Configuration
################################################################################

variable "create_vpc" {
  description = "Create a new VPC for the database (for POC/dev only)"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs_count" {
  description = "Number of availability zones to use (only used if create_vpc is true)"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID (required if create_vpc is false)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for the database (required if use_default_vpc is false)"
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Whether the database should be publicly accessible"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the database"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the database"
  type        = list(string)
  default     = []
}

################################################################################
# PostgreSQL Configuration
################################################################################

variable "postgres_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.2"
}

variable "postgres_parameter_group_family" {
  description = "The family of the DB parameter group"
  type        = string
  default     = "postgres17"
}

variable "postgres_major_engine_version" {
  description = "Major version of the DB engine"
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "The upper limit to which Amazon RDS can automatically scale the storage"
  type        = number
  default     = 100
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "storage_type" {
  description = "One of 'standard' (magnetic), 'gp2' (general purpose SSD), 'gp3', or 'io1' (provisioned IOPS SSD)"
  type        = string
  default     = "gp3"
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key"
  type        = string
  default     = ""
}

################################################################################
# Database Configuration
################################################################################

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "postgres"
}

variable "username" {
  description = "Username for the master DB user"
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "Password for the master DB user (only used if manage_master_user_password is false)"
  type        = string
  default     = null
  sensitive   = true
}

variable "manage_master_user_password" {
  description = "Set to true to allow RDS to manage the master user password in Secrets Manager"
  type        = bool
  default     = true
}

################################################################################
# High Availability Configuration
################################################################################

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

################################################################################
# Backup Configuration
################################################################################

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The window to perform maintenance in"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled"
  type        = bool
  default     = false
}

################################################################################
# Monitoring Configuration
################################################################################

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for exporting to CloudWatch logs"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "performance_insights_enabled" {
  description = "Specifies whether Performance Insights are enabled"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Amount of time in days to retain Performance Insights data"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected"
  type        = number
  default     = 0
}

################################################################################
# Parameter Group Configuration
################################################################################

variable "create_parameter_group" {
  description = "Whether to create a parameter group"
  type        = bool
  default     = true
}

variable "parameters" {
  description = "A list of DB parameters to apply"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

################################################################################
# Update Configuration
################################################################################

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
