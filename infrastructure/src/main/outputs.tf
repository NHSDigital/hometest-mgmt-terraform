################################################################################
# Outputs
################################################################################

#------------------------------------------------------------------------------
# ECR Outputs
#------------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.app.arn
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

#------------------------------------------------------------------------------
# Lambda Outputs
#------------------------------------------------------------------------------

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.app.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.app.arn
}

output "lambda_function_invoke_arn" {
  description = "Lambda function invoke ARN"
  value       = aws_lambda_function.app.invoke_arn
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Lambda execution role name"
  value       = aws_iam_role.lambda.name
}

#------------------------------------------------------------------------------
# API Gateway Outputs
#------------------------------------------------------------------------------

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = var.enable_api_gateway ? aws_apigatewayv2_api.app[0].id : null
}

output "api_gateway_endpoint" {
  description = "API Gateway HTTP API endpoint URL"
  value       = var.enable_api_gateway ? aws_apigatewayv2_api.app[0].api_endpoint : null
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  value       = var.enable_api_gateway ? aws_apigatewayv2_api.app[0].execution_arn : null
}

#------------------------------------------------------------------------------
# Lambda Function URL Outputs
#------------------------------------------------------------------------------

output "function_url" {
  description = "Lambda Function URL (if enabled)"
  value       = var.enable_function_url ? aws_lambda_function_url.app[0].function_url : null
}

#------------------------------------------------------------------------------
# Application URL Output
#------------------------------------------------------------------------------

output "app_url" {
  description = "Primary application URL"
  value = coalesce(
    var.enable_api_gateway ? aws_apigatewayv2_api.app[0].api_endpoint : null,
    var.enable_function_url ? aws_lambda_function_url.app[0].function_url : null,
    "No public endpoint configured"
  )
}

#------------------------------------------------------------------------------
# CloudWatch Outputs
#------------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN for Lambda"
  value       = aws_cloudwatch_log_group.lambda.arn
}

#------------------------------------------------------------------------------
# Deployment Helper Outputs
#------------------------------------------------------------------------------

output "docker_push_commands" {
  description = "Commands to push a Docker image to ECR"
  value       = <<-EOT
    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    # Build and tag (from app directory with Dockerfile)
    docker build --platform linux/${var.lambda_architecture == "arm64" ? "arm64" : "amd64"} -t ${aws_ecr_repository.app.repository_url}:latest .

    # Push to ECR
    docker push ${aws_ecr_repository.app.repository_url}:latest

    # Update Lambda to use new image
    aws lambda update-function-code --function-name ${aws_lambda_function.app.function_name} --image-uri ${aws_ecr_repository.app.repository_url}:latest
  EOT
}

output "github_actions_ecr_config" {
  description = "GitHub Actions configuration for ECR push"
  value = {
    registry       = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    repository     = aws_ecr_repository.app.name
    image_tag      = "latest"
    function_name  = aws_lambda_function.app.function_name
    aws_region     = var.aws_region
  }
}
