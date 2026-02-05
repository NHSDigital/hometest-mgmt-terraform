################################################################################
# HomeTest Service Application Outputs
################################################################################

#------------------------------------------------------------------------------
# Lambda Functions
#------------------------------------------------------------------------------

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.lambda_iam.role_arn
}

output "api1_lambda_arn" {
  description = "ARN of the API 1 Lambda"
  value       = module.api1_lambda.function_arn
}

output "api1_lambda_name" {
  description = "Name of the API 1 Lambda"
  value       = module.api1_lambda.function_name
}

output "api2_lambda_arn" {
  description = "ARN of the API 2 Lambda"
  value       = module.api2_lambda.function_arn
}

output "api2_lambda_name" {
  description = "Name of the API 2 Lambda"
  value       = module.api2_lambda.function_name
}

#------------------------------------------------------------------------------
# API Gateway 1
#------------------------------------------------------------------------------

output "api1_gateway_id" {
  description = "ID of API Gateway 1"
  value       = module.api_gateway_1.rest_api_id
}

output "api1_invoke_url" {
  description = "Invoke URL for API Gateway 1"
  value       = module.api_gateway_1.invoke_url
}

output "api1_custom_domain" {
  description = "Custom domain for API 1"
  value       = var.api1_custom_domain_name
}

output "api1_url" {
  description = "Full URL for API 1"
  value       = var.api1_custom_domain_name != null ? "https://${var.api1_custom_domain_name}" : module.api_gateway_1.invoke_url
}

#------------------------------------------------------------------------------
# API Gateway 2
#------------------------------------------------------------------------------

output "api2_gateway_id" {
  description = "ID of API Gateway 2"
  value       = module.api_gateway_2.rest_api_id
}

output "api2_invoke_url" {
  description = "Invoke URL for API Gateway 2"
  value       = module.api_gateway_2.invoke_url
}

output "api2_custom_domain" {
  description = "Custom domain for API 2"
  value       = var.api2_custom_domain_name
}

output "api2_url" {
  description = "Full URL for API 2"
  value       = var.api2_custom_domain_name != null ? "https://${var.api2_custom_domain_name}" : module.api_gateway_2.invoke_url
}

#------------------------------------------------------------------------------
# CloudFront SPA
#------------------------------------------------------------------------------

output "spa_bucket_id" {
  description = "S3 bucket ID for SPA static assets"
  value       = module.cloudfront_spa.s3_bucket_id
}

output "spa_bucket_arn" {
  description = "S3 bucket ARN for SPA static assets"
  value       = module.cloudfront_spa.s3_bucket_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront_spa.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront_spa.distribution_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront_spa.distribution_domain_name
}

output "spa_url" {
  description = "Full URL for SPA"
  value       = length(var.spa_custom_domain_names) > 0 ? "https://${var.spa_custom_domain_names[0]}" : module.cloudfront_spa.distribution_url
}

#------------------------------------------------------------------------------
# Environment URLs Summary
#------------------------------------------------------------------------------

output "environment_urls" {
  description = "All environment URLs"
  value = {
    ui   = length(var.spa_custom_domain_names) > 0 ? "https://${var.spa_custom_domain_names[0]}" : module.cloudfront_spa.distribution_url
    api1 = var.api1_custom_domain_name != null ? "https://${var.api1_custom_domain_name}" : module.api_gateway_1.invoke_url
    api2 = var.api2_custom_domain_name != null ? "https://${var.api2_custom_domain_name}" : module.api_gateway_2.invoke_url
  }
}

#------------------------------------------------------------------------------
# Deployment Commands
#------------------------------------------------------------------------------

output "deploy_commands" {
  description = "Commands to deploy application code"
  value       = <<-EOT
# Deploy API 1 Lambda:
aws s3 cp api1-handler.zip s3://${var.deployment_bucket_id}/lambdas/${var.environment}/
aws lambda update-function-code --function-name ${module.api1_lambda.function_name} --s3-bucket ${var.deployment_bucket_id} --s3-key lambdas/${var.environment}/api1-handler.zip

# Deploy API 2 Lambda:
aws s3 cp api2-handler.zip s3://${var.deployment_bucket_id}/lambdas/${var.environment}/
aws lambda update-function-code --function-name ${module.api2_lambda.function_name} --s3-bucket ${var.deployment_bucket_id} --s3-key lambdas/${var.environment}/api2-handler.zip

# Deploy SPA:
aws s3 sync ./dist s3://${module.cloudfront_spa.s3_bucket_id} --delete
aws cloudfront create-invalidation --distribution-id ${module.cloudfront_spa.distribution_id} --paths "/*"
EOT
}
