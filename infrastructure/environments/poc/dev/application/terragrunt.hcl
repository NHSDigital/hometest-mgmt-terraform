# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - Application (Lambda) for DEV Environment
# This deploys the Lambda function for the dev environment
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/application"
}

# Dependencies
dependency "network" {
  config_path = "../../core/network"

  mock_outputs = {
    private_subnet_ids       = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    lambda_security_group_id = "sg-mock"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
  # mock_outputs_allowed_terraform_commands = ["validate", "plan", "apply", "destroy"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEV Environment Application Configuration
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Lambda Configuration
  lambda_name        = "api"
  lambda_description = "HomeTest API Lambda for dev environment"
  lambda_handler     = "index.handler"
  lambda_runtime     = "nodejs20.x"
  lambda_timeout     = 30
  lambda_memory_size = 256

  # Lambda artifact configuration
  # Option 1: Deploy from local zip (for initial deployment)
  # Build with: make package-lambda
  lambda_filename = "${get_repo_root()}/artifacts/api.zip"

  # Option 2: Deploy from S3 (for CI/CD - uncomment and comment out lambda_filename)
  # Upload with: make upload-lambda
  # lambda_s3_bucket = "nhs-hometest-poc-dev-lambda-artifacts"
  # lambda_s3_key    = "api.zip"

  lambda_source_code_hash = null # Set to filebase64sha256 for change detection

  # VPC Configuration - deploy Lambda in VPC for RDS access
  enable_vpc             = true
  vpc_subnet_ids         = dependency.network.outputs.private_subnet_ids
  vpc_security_group_ids = [dependency.network.outputs.lambda_security_group_id]

  # Environment Variables
  environment_variables = {
    NODE_ENV    = "development"
    LOG_LEVEL   = "debug"
    ENVIRONMENT = "dev"
  }

  # Tracing
  enable_xray_tracing = true

  # Concurrency - no reservation for dev
  reserved_concurrent_executions = -1

  # Artifacts bucket - create for dev
  create_artifacts_bucket  = true
  artifacts_retention_days = 30

  # Logging
  log_retention_days = 30

  # Alarms - create but no actions for dev
  create_alarms   = true
  error_threshold = 10
  alarm_actions   = []
  ok_actions      = []
}
