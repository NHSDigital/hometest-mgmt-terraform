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
# DEPENDENCIES - Use the shared network VPC for connectivity with Lambda
# ---------------------------------------------------------------------------------------------------------------------

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id                   = "vpc-mock12345"
    data_subnet_ids          = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    lambda_security_group_id = "sg-mock-lambda"
    private_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# POC Environment Configuration
# PostgreSQL 18.1 on db.t4g.micro (cheapest ARM-based instance)
# Using shared network VPC for Lambda connectivity
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Use the shared network VPC (not creating a new one)
  create_vpc = false
  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.data_subnet_ids

  # Storage autoscaling - reduced for POC (default is 100 GB)
  max_allocated_storage = 50

  # Database name - POC specific
  db_name = "hometest_poc"

  # Network Security - Allow Lambda security group to connect
  allowed_security_group_ids = [dependency.network.outputs.lambda_security_group_id]
  # Also allow from private subnets CIDR for flexibility
  allowed_cidr_blocks = dependency.network.outputs.private_subnet_cidrs

  # Backup - minimal for POC (default is 7 days)
  backup_retention_period = 3
  skip_final_snapshot     = true  # Allow destruction without final snapshot
  deletion_protection     = false # Allow deletion for POC

  # Apply changes immediately in POC (default is false)
  apply_immediately = true
}
