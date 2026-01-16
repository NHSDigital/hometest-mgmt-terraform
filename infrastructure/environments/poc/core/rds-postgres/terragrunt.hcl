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
  create_vpc = true

  # Storage autoscaling - reduced for POC (default is 100 GB)
  max_allocated_storage = 50

  # Database name - POC specific
  db_name = "hometest_poc"

  # Network - Allow access from VPC CIDR for POC
  allowed_cidr_blocks = ["10.0.0.0/16"]

  # Backup - minimal for POC (default is 7 days)
  backup_retention_period = 3
  skip_final_snapshot     = true  # Allow destruction without final snapshot
  deletion_protection     = false # Allow deletion for POC

  # Apply changes immediately in POC (default is false)
  apply_immediately = true
}
