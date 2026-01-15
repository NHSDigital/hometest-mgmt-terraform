# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This deploys a PostgreSQL RDS instance for POC environment
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Configure the version of the module to use in this environment
terraform {
  source = "../../../..//src/rds-postgres"
}

# ---------------------------------------------------------------------------------------------------------------------
# POC Environment Configuration
# PostgreSQL 18.1 on db.t4g.micro (cheapest ARM-based instance)
# Creating a simple VPC for the database
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Create a simple VPC for POC
  create_vpc    = true
  vpc_cidr      = "10.0.0.0/16"
  vpc_azs_count = 2 # 2 AZs for subnet group requirement

  # PostgreSQL 18.1 - Latest stable version
  postgres_engine_version         = "18.1"
  postgres_parameter_group_family = "postgres18"
  postgres_major_engine_version   = "18"

  # db.t4g.micro - Cheapest stable instance (ARM-based Graviton2)
  # 2 vCPUs, 1 GiB RAM, ~$0.016/hour (~$12/month)
  instance_class = "db.t4g.micro"

  # Storage - minimal for POC
  allocated_storage     = 20 # Start with 20 GB
  max_allocated_storage = 50 # Allow autoscaling up to 50 GB
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name                     = "hometest_poc"
  username                    = "postgres"
  manage_master_user_password = true # AWS Secrets Manager

  # Network - Allow access from VPC CIDR for POC
  publicly_accessible = false
  allowed_cidr_blocks = ["10.0.0.0/16"] # Allow access from entire VPC

  # No Multi-AZ for POC (cost savings)
  multi_az = false

  # Backup - minimal for POC
  backup_retention_period = 3 # 3 days only
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  skip_final_snapshot     = true  # Skip final snapshot for POC
  deletion_protection     = false # Allow deletion for POC

  # Monitoring - disabled for cost savings in POC
  performance_insights_enabled = false
  monitoring_interval          = 0 # Disable enhanced monitoring

  # Logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Auto minor version upgrades enabled
  auto_minor_version_upgrade = true
  apply_immediately          = true # Apply changes immediately in POC

  # Tags
  tags = {
    Environment = "poc"
    ManagedBy   = "terragrunt"
    CostCenter  = "poc-testing"
  }
}
