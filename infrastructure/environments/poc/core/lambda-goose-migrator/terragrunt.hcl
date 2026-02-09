# Terragrunt config for Goose Lambda
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/lambda-goose-migrator"
}

dependencies {
  paths = [
    "../network",
    "../rds-postgres"
  ]
}

inputs = {
  # Compose the DB URL using dependency outputs
  db_url = join("", [
    "postgres://",
    dependency.rds-postgres.outputs.db_instance_username,
    ":",
    "${get_secret(dependency.rds-postgres.outputs.db_instance_master_user_secret_arn, \"password\")}" ,
    "@",
    dependency.rds-postgres.outputs.db_instance_address,
    ":",
    dependency.rds-postgres.outputs.db_instance_port,
    "/",
    dependency.rds-postgres.outputs.db_instance_name,
    "?sslmode=disable"
  ])
  # Optionally pass secret ARN if Lambda needs to fetch secrets directly
  db_secret_arn = dependency.rds-postgres.outputs.db_instance_master_user_secret_arn

  # Network configuration for Lambda
  subnet_ids         = dependency.network.outputs.data_subnet_ids
  security_group_ids = [dependency.rds-postgres.outputs.security_group_id]
}
