################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"
  account_id      = data.aws_caller_identity.current.account_id
  region          = data.aws_region.current.id

  # Use provided VPC or create new one
  vpc_id     = var.create_vpc ? aws_vpc.main[0].id : var.vpc_id
  subnet_ids = var.create_vpc ? aws_subnet.database[*].id : var.subnet_ids

  common_tags = merge(var.tags, {
    Component = "database"
  })
}

################################################################################
# VPC (Optional - for POC environments)
################################################################################

resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-igw"
  })
}

resource "aws_subnet" "database" {
  count = var.create_vpc ? var.vpc_azs_count : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-db-subnet-${count.index + 1}"
    Tier = "database"
  })
}

resource "aws_route_table" "database" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-db-rt"
  })
}

resource "aws_route_table_association" "database" {
  count = var.create_vpc ? var.vpc_azs_count : 0

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

################################################################################
# RDS PostgreSQL Module
################################################################################

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  identifier = "${local.resource_prefix}-postgres"
  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  # Engine configuration
  engine_version          = var.postgres_engine_version
  parameter_group_family  = var.postgres_parameter_group_family
  major_engine_version    = var.postgres_major_engine_version
  instance_class          = var.instance_class

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
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  skip_final_snapshot    = var.skip_final_snapshot
  deletion_protection    = var.deletion_protection

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
