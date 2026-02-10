################################################################################
# API Gateway Module Outputs
################################################################################

output "rest_api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.this.id
}

output "rest_api_arn" {
  description = "ARN of the REST API"
  value       = aws_api_gateway_rest_api.this.arn
}

output "rest_api_root_resource_id" {
  description = "Root resource ID of the REST API"
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "rest_api_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  description = "Name of the deployment stage"
  value       = try(aws_api_gateway_stage.this[0].stage_name, var.stage_name)
}

output "stage_arn" {
  description = "ARN of the deployment stage"
  value       = try(aws_api_gateway_stage.this[0].arn, null)
}

output "invoke_url" {
  description = "URL to invoke the API"
  value       = try(aws_api_gateway_stage.this[0].invoke_url, null)
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = try(aws_api_gateway_domain_name.this[0].domain_name, null)
}

output "custom_domain_regional_domain_name" {
  description = "Regional domain name of custom domain (for Route53 alias)"
  value       = try(aws_api_gateway_domain_name.this[0].regional_domain_name, null)
}

output "custom_domain_regional_zone_id" {
  description = "Regional zone ID of custom domain (for Route53 alias)"
  value       = try(aws_api_gateway_domain_name.this[0].regional_zone_id, null)
}
