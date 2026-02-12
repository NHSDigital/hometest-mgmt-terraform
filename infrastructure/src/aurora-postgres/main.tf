################################################################################
# Data Sources - Reference Network Module Resources
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  # Use VPC from network module (passed via variables from Terragrunt dependency)
  vpc_id = var.vpc_id

  common_tags = merge(var.tags, {
    Component = "rds-postgres"
  })
}

################################################################################
# RDS PostgreSQL Module
################################################################################

module "aurora_db" {
  source = "../../modules/aurora-postgres"

  identifier = "${local.resource_prefix}-postgres"
  vpc_id     = local.vpc_id

  # Use DB subnet group from network module
  db_subnet_group_name = var.db_subnet_group_name

  # Aurora Serverless v2 configuration
  engine_version              = var.engine_version
  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = true

  number_of_instances = var.number_of_instances

  serverlessv2_min_capacity = var.serverlessv2_min_capacity
  serverlessv2_max_capacity = var.serverlessv2_max_capacity

  storage_encrypted = var.storage_encrypted

  # Network access
  allowed_cidr_blocks        = var.allowed_cidr_blocks
  allowed_security_group_ids = var.allowed_security_group_ids
  publicly_accessible        = var.publicly_accessible

  # Encryption and backup
  kms_key_id              = var.kms_key_id
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  # Updates
  apply_immediately = var.apply_immediately

  tags = local.common_tags
}
