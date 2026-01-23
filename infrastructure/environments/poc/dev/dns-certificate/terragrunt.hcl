# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - DNS Certificate for DEV Environment
# This provisions ACM certificate and Route53 records for dev.hometest.service.nhs.uk
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/dns-certificate"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEV Environment DNS/Certificate Configuration
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Domain Configuration
  base_domain_name        = "hometest.service.nhs.uk"
  additional_domain_names = []

  # API Gateway integration will be configured after api-gateway is deployed
  # These will be updated with dependency once api-gateway module is deployed
  create_api_gateway_record        = false
  api_gateway_regional_domain_name = ""
  api_gateway_regional_zone_id     = ""

  # Health check - enable after API is live
  create_health_check            = false
  health_check_path              = "/health"
  health_check_failure_threshold = 3
  health_check_request_interval  = 30

  # Alarms
  alarm_actions = []
  ok_actions    = []
}
