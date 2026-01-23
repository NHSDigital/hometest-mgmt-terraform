################################################################################
# Outputs - IAM Developer Role Module
################################################################################

#------------------------------------------------------------------------------
# Role Outputs
#------------------------------------------------------------------------------

output "role_arn" {
  description = "The ARN of the developer IAM role"
  value       = aws_iam_role.developer.arn
}

output "role_name" {
  description = "The name of the developer IAM role"
  value       = aws_iam_role.developer.name
}

output "role_id" {
  description = "The ID of the developer IAM role"
  value       = aws_iam_role.developer.id
}

output "role_unique_id" {
  description = "The unique ID of the developer IAM role"
  value       = aws_iam_role.developer.unique_id
}

#------------------------------------------------------------------------------
# AFT Integration Outputs
#------------------------------------------------------------------------------

output "aft_role_reference" {
  description = "Role ARN formatted for AWS AFT account request"
  value       = aws_iam_role.developer.arn
}

output "aft_config" {
  description = "Configuration block for AWS AFT integration"
  value = {
    role_arn          = aws_iam_role.developer.arn
    role_name         = aws_iam_role.developer.name
    environment       = var.environment
    account_id        = var.aws_account_id
    aft_trust_enabled = var.enable_aft_trust
  }
}

#------------------------------------------------------------------------------
# Permission Scope Outputs
#------------------------------------------------------------------------------

output "permission_scope" {
  description = "Description of the permission scope for this role"
  value = {
    environment        = var.environment
    resource_pattern   = "${var.project_name}-${var.aws_account_shortname}-${var.environment}*"
    lambda_access      = "full (create, update, invoke)"
    api_gateway_access = "full (create, update, delete)"
    logs_access        = "read-only"
    cloudtrail_access  = "read-only"
    s3_access          = "artifacts bucket only"
    kms_access         = "environment keys only"
  }
}
