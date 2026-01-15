################################################################################
# RDS PostgreSQL Module
################################################################################

locals {
  # Common tags for cost allocation and resource management
  common_tags = merge(
    var.tags,
    {
      # Resource identification
      Name = var.identifier
      
      # Technical metadata
      Service       = "rds"
      Engine        = "postgresql"
      EngineVersion = var.engine_version
      InstanceClass = var.instance_class
      
      # Management metadata
      ManagedBy = "terraform"
      Module    = "rds-postgres"
      
      # Cost allocation
      CostCenter = try(var.tags["CostCenter"], "")
      Owner      = try(var.tags["Owner"], "")
    }
  )

  # Resource-specific tags
  security_group_tags = merge(
    local.common_tags,
    {
      Name         = "${var.identifier}-sg"
      ResourceType = "security-group"
    }
  )

  db_instance_tags = merge(
    local.common_tags,
    {
      ResourceType     = "db-instance"
      MultiAZ          = tostring(var.multi_az)
      StorageEncrypted = tostring(var.storage_encrypted)
    }
  )

  db_subnet_group_tags = merge(
    local.common_tags,
    {
      Name         = "${var.identifier}-subnet-group"
      ResourceType = "db-subnet-group"
    }
  )

  db_parameter_group_tags = merge(
    local.common_tags,
    {
      Name         = "${var.identifier}-params"
      ResourceType = "db-parameter-group"
      Family       = var.parameter_group_family
    }
  )
}

################################################################################
# RDS PostgreSQL Instance
################################################################################

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = var.identifier

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.engine_version
  family               = var.parameter_group_family
  major_engine_version = var.major_engine_version
  instance_class       = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = var.storage_encrypted
  storage_type          = var.storage_type
  iops                  = var.iops
  kms_key_id            = var.kms_key_id

  # Database configuration
  db_name  = var.db_name
  username = var.username
  port     = 5432

  # Password management
  manage_master_user_password = var.manage_master_user_password
  password                    = var.manage_master_user_password ? null : var.password

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [module.security_group.security_group_id]
  publicly_accessible    = var.publicly_accessible

  # Subnet group (create if not provided)
  create_db_subnet_group = var.db_subnet_group_name == null
  subnet_ids             = var.subnet_ids

  # Multi-AZ and availability
  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : var.availability_zone

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  skip_final_snapshot    = var.skip_final_snapshot
  copy_tags_to_snapshot  = true

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Performance Insights
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? var.monitoring_role_arn : null
  create_monitoring_role = var.monitoring_interval > 0 && var.monitoring_role_arn == null

  # Parameter group
  create_db_parameter_group = var.create_parameter_group
  parameter_group_name      = var.parameter_group_name
  parameters                = var.parameters

  # Option group
  create_db_option_group = var.create_option_group
  option_group_name      = var.option_group_name
  options                = var.options

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately
  apply_immediately = var.apply_immediately

  # Blue/green deployment
  blue_green_update = var.blue_green_update

  # Tags - applied to RDS instance, subnet group, parameter group, option group
  tags                      = local.db_instance_tags
  db_subnet_group_tags      = local.db_subnet_group_tags
  db_parameter_group_tags   = local.db_parameter_group_tags
  db_option_group_tags      = local.db_parameter_group_tags  # Reuse parameter group tags
}
