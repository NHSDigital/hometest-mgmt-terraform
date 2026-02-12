# Terragrunt config for Goose Lambda
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/lambda-goose-migrator"
}

dependency "aurora-postgres" {
  config_path = "../aurora-postgres"
}

dependency "network" {
  config_path = "../network"
}

inputs = {
  # Pass DB connection info as separate variables for Lambda to construct the URL
  db_username   = dependency.aurora-postgres.outputs.cluster_master_username
  db_address    = dependency.aurora-postgres.outputs.cluster_endpoint
  db_port       = dependency.aurora-postgres.outputs.cluster_port
  db_name       = dependency.aurora-postgres.outputs.cluster_database_name
  db_cluster_id = dependency.aurora-postgres.outputs.cluster_id

  # Network configuration for Lambda
  subnet_ids = dependency.network.outputs.private_subnet_ids
  security_group_ids = [
    dependency.network.outputs.lambda_rds_security_group_id,
    dependency.network.outputs.lambda_security_group_id
  ]
}
