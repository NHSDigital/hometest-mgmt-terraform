# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  # 781863586270 aws.hometest.poc@nhsdigital.nhs.uk
  account_fullname   = "NHS HomeTest POC"
  account_name      = "hometest-poc"
  account_shortname = "poc"
  aws_account_id = "781863586270"
}
