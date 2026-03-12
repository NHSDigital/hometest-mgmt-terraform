################################################################################
# Developer IAM Module Outputs
################################################################################

output "role_name" {
  description = "Name of the developer deployment role"
  value       = aws_iam_role.developer_deploy.name
}

output "role_arn" {
  description = "ARN of the developer deployment role"
  value       = aws_iam_role.developer_deploy.arn
}

output "role_id" {
  description = "ID of the developer deployment role"
  value       = aws_iam_role.developer_deploy.id
}

output "assume_role_command" {
  description = "AWS CLI command to assume the role"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.developer_deploy.arn} --role-session-name developer-session"
}

output "assume_role_profile_config" {
  description = "AWS CLI profile configuration for ~/.aws/config"
  value       = <<-EOT
[profile ${var.project_name}-${var.environment}-deploy]
role_arn = ${aws_iam_role.developer_deploy.arn}
source_profile = default
mfa_serial = arn:aws:iam::DEVELOPER_ACCOUNT_ID:mfa/USERNAME
EOT
}
