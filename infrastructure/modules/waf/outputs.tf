################################################################################
# WAF Module Outputs
################################################################################

output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_capacity" {
  description = "Web ACL capacity units used"
  value       = aws_wafv2_web_acl.this.capacity
}

output "log_group_name" {
  description = "Name of the CloudWatch log group (if logging enabled)"
  value       = try(aws_cloudwatch_log_group.waf[0].name, null)
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group (if logging enabled)"
  value       = try(aws_cloudwatch_log_group.waf[0].arn, null)
}
