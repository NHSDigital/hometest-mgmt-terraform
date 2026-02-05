# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terragrunt is a thin wrapper for Terraform/OpenTofu that provides extra tools for working with multiple modules,
# remote state, and locking: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  # region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Automatically load global variables
  global_vars = read_terragrunt_config(find_in_parent_folders("_envcommon/all.hcl"))

  # Extract the variables we need for easy access
  region       = local.global_vars.locals.aws_region
  account_name = local.account_vars.locals.aws_account_name
  account_id   = local.account_vars.locals.aws_account_id

  environment = local.environment_vars.locals.environment
}

remote_state {
  backend = "s3"
  config = {
    bucket       = "nhs-hometest-poc-core-s3-tfstate"
    use_lockfile = true
    key          = "${local.account_name}-${local.environment}-${basename(path_relative_to_include())}.tfstate"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:eu-west-2:781863586270:key/3e87d63f-febc-4dd4-a771-92c3c07a51f5"
    region       = local.region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit. This is especially helpful with multi-account configs
# where terraform_remote_state data sources are placed directly into the modules.
inputs = merge(
  local.global_vars.locals,
  local.account_vars.locals,
  local.environment_vars.locals,
  {
    tags = {
      Owner       = "platform-team"
      CostCenter  = "infrastructure"
      Project     = local.global_vars.locals.project_name
      Environment = local.environment
      ManagedBy   = "terraform"
      Repository  = local.global_vars.locals.github_repo
    }
  }
)
