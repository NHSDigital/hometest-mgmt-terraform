# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  environment                = "uat"
  enable_wiremock            = true
  wiremock_bypass_waf        = false # Use shared ALB — WAF allowlist rule exempts WireMock traffic
  wiremock_scheduled_scaling = true  # Scale to 0 outside business hours (Mon-Fri 9AM-6PM UTC)
}
