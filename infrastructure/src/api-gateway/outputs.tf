################################################################################
# Outputs - API Gateway Module
################################################################################

#------------------------------------------------------------------------------
# API Gateway Outputs
#------------------------------------------------------------------------------

output "rest_api_id" {
  description = "The ID of the REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "rest_api_arn" {
  description = "The ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "rest_api_execution_arn" {
  description = "The execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "rest_api_name" {
  description = "The name of the REST API"
  value       = aws_api_gateway_rest_api.main.name
}

#------------------------------------------------------------------------------
# Stage Outputs
#------------------------------------------------------------------------------

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "The ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.main.arn
}

output "invoke_url" {
  description = "The URL to invoke the API Gateway (default endpoint)"
  value       = aws_api_gateway_stage.main.invoke_url
}

#------------------------------------------------------------------------------
# Custom Domain Outputs
#------------------------------------------------------------------------------

output "custom_domain_name" {
  description = "The custom domain name"
  value       = var.create_custom_domain ? aws_api_gateway_domain_name.main[0].domain_name : null
}

output "custom_domain_regional_domain_name" {
  description = "The regional domain name for the custom domain (use for Route53 alias)"
  value       = var.create_custom_domain ? aws_api_gateway_domain_name.main[0].regional_domain_name : null
}

output "custom_domain_regional_zone_id" {
  description = "The regional zone ID for the custom domain (use for Route53 alias)"
  value       = var.create_custom_domain ? aws_api_gateway_domain_name.main[0].regional_zone_id : null
}

output "api_endpoint" {
  description = "The API endpoint URL (custom domain if configured, otherwise invoke URL)"
  value       = var.create_custom_domain ? "https://${var.domain_name}/${var.stage_name}" : aws_api_gateway_stage.main.invoke_url
}

#------------------------------------------------------------------------------
# mTLS Outputs
#------------------------------------------------------------------------------

output "mtls_enabled" {
  description = "Whether mTLS is enabled"
  value       = var.enable_mtls
}

output "truststore_bucket_id" {
  description = "The S3 bucket ID for the mTLS truststore"
  value       = var.enable_mtls ? aws_s3_bucket.truststore[0].id : null
}

output "truststore_bucket_arn" {
  description = "The S3 bucket ARN for the mTLS truststore"
  value       = var.enable_mtls ? aws_s3_bucket.truststore[0].arn : null
}

#------------------------------------------------------------------------------
# CloudWatch Logs Outputs
#------------------------------------------------------------------------------

output "access_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for access logs"
  value       = aws_cloudwatch_log_group.api_gateway_access.arn
}

output "access_log_group_name" {
  description = "The name of the CloudWatch Log Group for access logs"
  value       = aws_cloudwatch_log_group.api_gateway_access.name
}

#------------------------------------------------------------------------------
# KMS Outputs
#------------------------------------------------------------------------------

output "kms_key_arn" {
  description = "The ARN of the KMS key for API Gateway"
  value       = aws_kms_key.api_gateway.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key for API Gateway"
  value       = aws_kms_key.api_gateway.key_id
}

#------------------------------------------------------------------------------
# WAF Association Outputs (for downstream WAF module)
#------------------------------------------------------------------------------

output "stage_arn_for_waf" {
  description = "The stage ARN formatted for WAF association"
  value       = aws_api_gateway_stage.main.arn
}
