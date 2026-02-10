# Terragrunt config for Liquibase Lambda
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/lambda-liquibase-migrator"
}

dependency "rds-postgres" {
  config_path = "../rds-postgres"
}

dependency "network" {
  config_path = "../network"
}

inputs = {
  db_username   = dependency.rds-postgres.outputs.db_instance_username
  db_address    = dependency.rds-postgres.outputs.db_instance_address
  db_port       = dependency.rds-postgres.outputs.db_instance_port
  db_name       = dependency.rds-postgres.outputs.db_instance_name
  db_secret_arn = dependency.rds-postgres.outputs.db_instance_master_user_secret_arn

  subnet_ids         = dependency.network.outputs.private_subnet_ids
  security_group_ids = [
    dependency.network.outputs.lambda_rds_security_group_id,
    dependency.network.outputs.lambda_security_group_id
  ]
}
