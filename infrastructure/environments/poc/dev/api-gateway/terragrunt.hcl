# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - API Gateway with mTLS for DEV Environment
# This provisions API Gateway with mTLS termination for dev.hometest.service.nhs.uk
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/api-gateway"
}

# Dependencies
dependency "application" {
  config_path = "../application"

  mock_outputs = {
    lambda_function_name = "nhs-hometest-poc-dev-api"
    lambda_invoke_arn    = "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:781863586270:function:nhs-hometest-poc-dev-api/invocations"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "dns_certificate" {
  config_path = "../dns-certificate"

  mock_outputs = {
    certificate_arn  = "arn:aws:acm:eu-west-2:781863586270:certificate/mock-cert-id"
    environment_fqdn = "dev.hometest.service.nhs.uk"
    zone_id          = "Z065277424BZQXJTSWKE4"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEV Environment API Gateway Configuration
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Lambda Integration
  lambda_function_name = dependency.application.outputs.lambda_function_name
  lambda_invoke_arn    = dependency.application.outputs.lambda_invoke_arn

  # mTLS Configuration
  # Enable mTLS - requires client certificates
  # Initially disabled until client CA certificates are provisioned
  enable_mtls        = false
  truststore_content = ""

  # Custom Domain Configuration
  create_custom_domain = true
  domain_name          = dependency.dns_certificate.outputs.environment_fqdn
  certificate_arn      = dependency.dns_certificate.outputs.certificate_arn

  # Route53 DNS Record
  create_dns_record = true
  route53_zone_id   = dependency.dns_certificate.outputs.zone_id

  # Stage Configuration
  stage_name = "v1"

  # Authorization - None initially, can add Cognito/IAM later
  authorization_type = "NONE"

  # Logging
  log_retention_days = 30
  logging_level      = "INFO"
  data_trace_enabled = true # Enable for dev debugging

  # Throttling - relaxed for dev
  throttling_burst_limit = 1000
  throttling_rate_limit  = 2000

  # Features
  enable_xray_tracing      = true
  enable_compression       = true
  minimum_compression_size = 1024
}
