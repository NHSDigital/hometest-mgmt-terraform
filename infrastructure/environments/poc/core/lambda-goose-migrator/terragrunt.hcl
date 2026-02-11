# Terragrunt config for Goose Lambda
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/lambda-goose-migrator"
}

dependency "rds-postgres" {
  config_path = "../rds-postgres"
}

dependency "network" {
  config_path = "../network"
}

inputs = {
  # Pass DB connection info as separate variables for Lambda to construct the URL
  db_username   = dependency.rds-postgres.outputs.db_instance_username
  db_address    = dependency.rds-postgres.outputs.db_instance_address
  db_port       = dependency.rds-postgres.outputs.db_instance_port
  db_name       = dependency.rds-postgres.outputs.db_instance_name
  db_secret_arn = dependency.rds-postgres.outputs.db_instance_master_user_secret_arn

  # Network configuration for Lambda
  subnet_ids = dependency.network.outputs.private_subnet_ids
  security_group_ids = [
    dependency.network.outputs.lambda_rds_security_group_id,
    dependency.network.outputs.lambda_security_group_id
  ]
}
