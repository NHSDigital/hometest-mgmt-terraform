locals{
  # AWS Configuration
  aws_region = "eu-west-2"

  # Project Configuration
  project_name = "nhs-hometest"

  # GitHub Configuration
  github_repo  = "NHSDigital/hometest-mgmt-terraform"

  # Branches allowed to run Terraform apply
  github_branches = [
    "main",
    "develop"
  ]

  # GitHub environments allowed to run Terraform
  github_environments = [
    "dev",
    # "staging",
    # "prod"
  ]

  # Allow all branches to assume the OIDC role (disables branch/environment restrictions)
  # WARNING: Set to true only for development/testing. Keep false for production.
  github_allow_all_branches = false

  # Security and Logging Settings
  enable_state_bucket_logging            = true
  state_bucket_retention_days            = 90
  enable_dynamodb_point_in_time_recovery = true
  kms_key_deletion_window_days           = 30

  # Additional IAM Policy ARNs to attach to the GitHub Actions role
  # Uncomment and add policies as needed
  # additional_iam_policy_arns = [
  #   "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
  #   "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  # ]

}
