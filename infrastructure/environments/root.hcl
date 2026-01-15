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
  # generic_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/common/generic.hcl").locals

  # Extract the variables we need for easy access
  region       = local.global_vars.locals.aws_region
  account_name = local.account_vars.locals.aws_account_name
  account_id   = local.account_vars.locals.aws_account_id

  environment = local.environment_vars.locals.environment
}

# Generate an AWS provider block
# generate "provider" {
#   path      = "providers.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "aws" {
#   region = "${local.aws_region}"

#   # Only these AWS Account IDs may be operated on by this template
#   allowed_account_ids = ["${local.account_id}"]
# }
# EOF
# }

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
# remote_state {
#   backend = "s3"
#   config = {
#     encrypt        = true
#     bucket         = "${get_env("TG_BUCKET_PREFIX", "")}terragrunt-example-tf-state-${local.account_name}-${local.aws_region}"
#     key            = "${path_relative_to_include()}/tf.tfstate"
#     region         = local.aws_region
#     dynamodb_table = "tf-locks"
#   }
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
# }

remote_state {
  backend = "s3"
  config = {
    bucket         = "nhs-hometest-poc-core-s3-tfstate"
    dynamodb_table = "nhs-hometest-poc-core-dynamodb-tfstate-lock"
    # key            = "${path_relative_to_include()}/tf.tfstate"
    key        = "${local.account_name}-${local.environment}-${basename(path_relative_to_include())}.tfstate"
    encrypt    = true
    kms_key_id = "arn:aws:kms:eu-west-2:781863586270:key/3e87d63f-febc-4dd4-a771-92c3c07a51f5"
    # kms_key_id = "arn:aws:kms:eu-west-2:781863586270:alias/nhs-hometest-poc-kms-tfstate-key"
    region = local.region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}


# Configure what repos to search when you run 'terragrunt catalog'
# catalog {
#   urls = [
#     "https://github.com/gruntwork-io/terragrunt-infrastructure-modules-example",
#     "https://github.com/gruntwork-io/terraform-aws-utilities",
#     "https://github.com/gruntwork-io/terraform-kubernetes-namespace"
#   ]
# }

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit. This is especially helpful with multi-account configs
# where terraform_remote_state data sources are placed directly into the modules.
inputs = merge(
  local.account_vars.locals,
  # local.region_vars.locals,
  local.environment_vars.locals,
  local.global_vars.locals,
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
