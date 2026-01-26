################################################################################
# Outputs - Application (Lambda) Module
################################################################################

#------------------------------------------------------------------------------
# Lambda Function Outputs
#------------------------------------------------------------------------------

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_invoke_arn" {
  description = "The invoke ARN of the Lambda function (for API Gateway integration)"
  value       = aws_lambda_function.main.invoke_arn
}

output "lambda_qualified_arn" {
  description = "The qualified ARN of the Lambda function (with version)"
  value       = aws_lambda_function.main.qualified_arn
}

output "lambda_version" {
  description = "The version of the Lambda function"
  value       = aws_lambda_function.main.version
}

output "lambda_source_code_size" {
  description = "The size of the Lambda function package in bytes"
  value       = aws_lambda_function.main.source_code_size
}

output "lambda_last_modified" {
  description = "The last modified date of the Lambda function"
  value       = aws_lambda_function.main.last_modified
}

#------------------------------------------------------------------------------
# Lambda Alias Outputs
#------------------------------------------------------------------------------

output "lambda_alias_arn" {
  description = "The ARN of the Lambda alias"
  value       = var.create_alias ? aws_lambda_alias.live[0].arn : null
}

output "lambda_alias_invoke_arn" {
  description = "The invoke ARN of the Lambda alias"
  value       = var.create_alias ? aws_lambda_alias.live[0].invoke_arn : null
}

#------------------------------------------------------------------------------
# IAM Role Outputs
#------------------------------------------------------------------------------

output "lambda_execution_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "The name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

#------------------------------------------------------------------------------
# CloudWatch Logs Outputs
#------------------------------------------------------------------------------

output "log_group_arn" {
  description = "The ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "log_group_name" {
  description = "The name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.name
}

#------------------------------------------------------------------------------
# KMS Outputs
#------------------------------------------------------------------------------

output "kms_key_arn" {
  description = "The ARN of the KMS key for Lambda"
  value       = aws_kms_key.lambda.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key for Lambda"
  value       = aws_kms_key.lambda.key_id
}

#------------------------------------------------------------------------------
# Artifacts Bucket Outputs
#------------------------------------------------------------------------------

output "artifacts_bucket_id" {
  description = "The ID of the S3 bucket for Lambda artifacts"
  value       = var.create_artifacts_bucket ? aws_s3_bucket.artifacts[0].id : null
}

output "artifacts_bucket_arn" {
  description = "The ARN of the S3 bucket for Lambda artifacts"
  value       = var.create_artifacts_bucket ? aws_s3_bucket.artifacts[0].arn : null
}

output "artifacts_bucket_domain_name" {
  description = "The domain name of the S3 bucket for Lambda artifacts"
  value       = var.create_artifacts_bucket ? aws_s3_bucket.artifacts[0].bucket_domain_name : null
}

#------------------------------------------------------------------------------
# Alarm Outputs
#------------------------------------------------------------------------------

output "error_alarm_arn" {
  description = "The ARN of the Lambda errors alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.lambda_errors[0].arn : null
}

output "duration_alarm_arn" {
  description = "The ARN of the Lambda duration alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.lambda_duration[0].arn : null
}

output "throttle_alarm_arn" {
  description = "The ARN of the Lambda throttles alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.lambda_throttles[0].arn : null
}
