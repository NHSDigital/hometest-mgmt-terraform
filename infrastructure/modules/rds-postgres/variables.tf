################################################################################
# Required Variables
################################################################################

variable "identifier" {
  description = "The name of the RDS instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.identifier))
    error_message = "Identifier must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 1-63 characters long."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where the database will be created"
  type        = string
}

################################################################################
# Engine Configuration
################################################################################

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "18.1"
}

variable "parameter_group_family" {
  description = "The family of the DB parameter group"
  type        = string
  default     = "postgres18"
}

variable "major_engine_version" {
  description = "Major version of the DB engine"
  type        = string
  default     = "18"
}

variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

################################################################################
# Storage Configuration
################################################################################

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

  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "Storage type must be one of: standard, gp2, gp3, io1, io2."
  }
}

variable "iops" {
  description = "The amount of provisioned IOPS. Setting this implies a storage_type of 'io1'"
  type        = number
  default     = null
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. If creating an encrypted replica, set this to the destination KMS ARN"
  type        = string
  default     = null
}

################################################################################
# Database Configuration
################################################################################

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = null
}

variable "username" {
  description = "Username for the master DB user"
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "Password for the master DB user. Required if manage_master_user_password is false"
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
# Network Configuration
################################################################################

variable "subnet_ids" {
  description = "A list of VPC subnet IDs for the DB subnet group. Required unless db_subnet_group_name is provided."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.subnet_ids) == 0 || length(var.subnet_ids) >= 2
    error_message = "If providing subnet_ids, you must provide at least 2 subnets for RDS subnet group."
  }
}

variable "db_subnet_group_name" {
  description = "Name of existing DB subnet group. If not provided, a new subnet group will be created using subnet_ids."
  type        = string
  default     = null
}

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the database. Cannot include 0.0.0.0/0 for security."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "Security best practice violation: Cannot allow access from 0.0.0.0/0 (internet). Use specific CIDR blocks or security groups."
  }

  validation {
    condition     = alltrue([for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All CIDR blocks must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the database"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for sg in var.allowed_security_group_ids : can(regex("^sg-[a-z0-9]+$", sg))])
    error_message = "All security group IDs must be valid format (sg-xxxxxxxx)."
  }
}

################################################################################
# High Availability Configuration
################################################################################

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "The AZ for the RDS instance (only used if multi_az is false)"
  type        = string
  default     = null
}

################################################################################
# Backup Configuration
################################################################################

variable "backup_retention_period" {
  description = "The days to retain backups for. Must be between 0 and 35. Set to 0 to disable automated backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
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
  default     = true
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
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Amount of time in days to retain Performance Insights data"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected. Valid values: 0, 1, 5, 10, 15, 30, 60. Set to 0 to disable enhanced monitoring."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "monitoring_role_arn" {
  description = "The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. Leave null to auto-create."
  type        = string
  default     = null
}

################################################################################
# Parameter and Option Groups
################################################################################

variable "create_parameter_group" {
  description = "Whether to create a parameter group"
  type        = bool
  default     = true
}

variable "parameter_group_name" {
  description = "Name of the DB parameter group to associate"
  type        = string
  default     = null
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

variable "create_option_group" {
  description = "Whether to create an option group"
  type        = bool
  default     = false
}

variable "option_group_name" {
  description = "Name of the option group"
  type        = string
  default     = null
}

variable "options" {
  description = "A list of options to apply"
  type        = any
  default     = []
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

variable "blue_green_update" {
  description = "Enables blue/green deployments for database updates"
  type = object({
    enabled = bool
  })
  default = {
    enabled = false
  }
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
