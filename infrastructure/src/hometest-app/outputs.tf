################################################################################
# HomeTest Service Application Outputs
################################################################################

# Deployment Artifacts
output "artifacts_bucket_id" {
  description = "S3 bucket ID for deployment artifacts"
  value       = module.deployment_artifacts.bucket_id
}

output "artifacts_bucket_arn" {
  description = "S3 bucket ARN for deployment artifacts"
  value       = module.deployment_artifacts.bucket_arn
}

# Lambda Functions
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.lambda_iam.role_arn
}

output "eligibility_test_info_lambda_arn" {
  description = "ARN of the eligibility-test-info Lambda"
  value       = module.eligibility_test_info_lambda.function_arn
}

output "order_router_lambda_arn" {
  description = "ARN of the order-router Lambda"
  value       = module.order_router_lambda.function_arn
}

output "hello_world_lambda_arn" {
  description = "ARN of the hello-world Lambda"
  value       = module.hello_world_lambda.function_arn
}

# API Gateway
output "api_gateway_id" {
  description = "ID of the REST API"
  value       = module.api_gateway.rest_api_id
}

output "api_gateway_invoke_url" {
  description = "URL to invoke the API"
  value       = module.api_gateway.invoke_url
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = module.api_gateway.stage_name
}

# CloudFront SPA
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

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = module.cloudfront_spa.distribution_url
}

# Developer Deployment
output "developer_role_arn" {
  description = "ARN of the developer deployment role"
  value       = module.developer_iam.role_arn
}

output "developer_role_assume_command" {
  description = "AWS CLI command to assume the developer role"
  value       = module.developer_iam.assume_role_command
}

output "developer_role_profile_config" {
  description = "AWS CLI profile configuration for developer role"
  value       = module.developer_iam.assume_role_profile_config
}

# Deployment Commands
output "deploy_lambda_command" {
  description = "Command to deploy a Lambda function"
  value       = <<-EOT
# Upload Lambda zip to S3:
aws s3 cp lambda.zip s3://${module.deployment_artifacts.bucket_id}/lambdas/<function-name>.zip

# Update Lambda function code:
aws lambda update-function-code \
  --function-name ${var.project_name}-${var.environment}-<function-name> \
  --s3-bucket ${module.deployment_artifacts.bucket_id} \
  --s3-key lambdas/<function-name>.zip
EOT
}

output "deploy_spa_command" {
  description = "Commands to deploy SPA to CloudFront"
  value       = <<-EOT
# Sync SPA build to S3:
aws s3 sync ./dist s3://${module.cloudfront_spa.s3_bucket_id} --delete

# Invalidate CloudFront cache:
aws cloudfront create-invalidation \
  --distribution-id ${module.cloudfront_spa.distribution_id} \
  --paths "/*"
EOT
}
