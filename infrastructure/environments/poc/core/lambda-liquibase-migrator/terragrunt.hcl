# Terragrunt config for Liquibase Lambda
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/lambda-liquibase-migrator"
}

dependencies {
  paths = [
    "../network",
    "../rds-postgres"
  ]
}

inputs = {
  db_username   = dependency.rds-postgres.outputs.db_instance_username
  db_address    = dependency.rds-postgres.outputs.db_instance_address
  db_port       = dependency.rds-postgres.outputs.db_instance_port
  db_name       = dependency.rds-postgres.outputs.db_instance_name
  db_secret_arn = dependency.rds-postgres.outputs.db_instance_master_user_secret_arn

  subnet_ids         = dependency.network.outputs.data_subnet_ids
  security_group_ids = [dependency.rds-postgres.outputs.security_group_id]
}
