################################################################################
# Data Sources - Reference Network Module Resources
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  # Use VPC from network module (passed via variables from Terragrunt dependency)
  vpc_id = var.vpc_id

  common_tags = merge(var.tags, {
    Component = "database"
  })
}

################################################################################
# RDS PostgreSQL Module
################################################################################

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  identifier = "${local.resource_prefix}-postgres"
  vpc_id     = local.vpc_id

  # Use DB subnet group from network module
  db_subnet_group_name = var.db_subnet_group_name

  # Engine configuration
  engine_version         = var.postgres_engine_version
  parameter_group_family = var.postgres_parameter_group_family
  major_engine_version   = var.postgres_major_engine_version
  instance_class         = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = var.storage_encrypted
  storage_type          = var.storage_type
  kms_key_id            = var.kms_key_id

  # Database configuration
  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = var.manage_master_user_password
  password                    = var.password

  # Network access
  publicly_accessible        = var.publicly_accessible
  allowed_cidr_blocks        = var.allowed_cidr_blocks
  allowed_security_group_ids = var.allowed_security_group_ids

  # High availability
  multi_az = var.multi_az

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  # Monitoring
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  monitoring_interval                   = var.monitoring_interval

  # Parameter group
  create_parameter_group = var.create_parameter_group
  parameters             = var.parameters

  # Updates
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = local.common_tags
}
