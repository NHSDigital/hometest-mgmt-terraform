################################################################################
# Outputs - WAF Module
################################################################################

#------------------------------------------------------------------------------
# Web ACL Outputs
#------------------------------------------------------------------------------

output "web_acl_id" {
  description = "The ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "The name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.name
}

output "web_acl_capacity" {
  description = "The Web ACL capacity units (WCUs) used by this Web ACL"
  value       = aws_wafv2_web_acl.main.capacity
}

#------------------------------------------------------------------------------
# IP Set Outputs
#------------------------------------------------------------------------------

output "ip_allowlist_arn" {
  description = "The ARN of the IP allowlist set"
  value       = var.enable_ip_allowlist && length(var.allowed_ip_addresses) > 0 ? aws_wafv2_ip_set.allowlist[0].arn : null
}

output "ip_blocklist_arn" {
  description = "The ARN of the IP blocklist set"
  value       = var.enable_ip_blocklist && length(var.blocked_ip_addresses) > 0 ? aws_wafv2_ip_set.blocklist[0].arn : null
}

#------------------------------------------------------------------------------
# Logging Outputs
#------------------------------------------------------------------------------

output "log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for WAF logs"
  value       = aws_cloudwatch_log_group.waf.arn
}

output "log_group_name" {
  description = "The name of the CloudWatch Log Group for WAF logs"
  value       = aws_cloudwatch_log_group.waf.name
}

#------------------------------------------------------------------------------
# KMS Outputs
#------------------------------------------------------------------------------

output "kms_key_arn" {
  description = "The ARN of the KMS key for WAF logs"
  value       = aws_kms_key.waf.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key for WAF logs"
  value       = aws_kms_key.waf.key_id
}

#------------------------------------------------------------------------------
# Association Outputs
#------------------------------------------------------------------------------

output "api_gateway_association_id" {
  description = "The ID of the WAF association with API Gateway"
  value       = length(aws_wafv2_web_acl_association.api_gateway) > 0 ? aws_wafv2_web_acl_association.api_gateway[0].id : null
}
