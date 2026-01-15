# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  # 781863586270 aws.hometest.poc@nhsdigital.nhs.uk
  aws_account_id        = "781863586270"
  aws_account_fullname  = "NHS HomeTest POC"
  aws_account_name      = "nhs-hometest-poc"
  aws_account_shortname = "poc"

  github_allow_all_branches = true
}
