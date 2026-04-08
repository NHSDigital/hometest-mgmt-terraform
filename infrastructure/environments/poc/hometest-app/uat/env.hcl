# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  environment         = "uat"
  enable_wiremock     = true
  wiremock_bypass_waf = true # Expose WireMock directly to internet (dedicated ALB, no WAF)
}
