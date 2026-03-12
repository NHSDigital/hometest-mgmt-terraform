################################################################################
# Lambda IAM Module Outputs
################################################################################

output "role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "role_id" {
  description = "ID of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.id
}

output "role_unique_id" {
  description = "Unique ID of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.unique_id
}
