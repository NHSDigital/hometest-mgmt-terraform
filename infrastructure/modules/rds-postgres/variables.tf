# Aurora module requires manage_master_user_password for password management
variable "manage_master_user_password" {
  description = "Set to true to allow RDS to manage the master user password in Secrets Manager. Cannot be set if master_password is provided."
  type        = bool
  default     = false
}
# Aurora module requires storage_encrypted for encryption control
variable "storage_encrypted" {
  description = "Specifies whether the DB cluster is encrypted. The default is true."
  type        = bool
  default     = true
}
# Aurora module requires db_subnet_group_name if not creating a new subnet group
variable "db_subnet_group_name" {
  description = "Name of the DB subnet group to use for the Aurora cluster. If not provided, the module will attempt to create one."
  type        = string
  default     = null
}
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

variable "serverlessv2_min_capacity" {
  description = "Minimum Aurora capacity units (ACUs) for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "serverlessv2_max_capacity" {
  description = "Maximum Aurora capacity units (ACUs) for Aurora Serverless v2"
  type        = number
  default     = 4
}

################################################################################
# Storage Configuration
################################################################################

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

################################################################################
# Network Configuration
################################################################################
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

variable "apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
