################################################################################
# SNS Module Outputs
################################################################################

#------------------------------------------------------------------------------
# Topic Outputs
#------------------------------------------------------------------------------

output "topic_id" {
  description = "The ARN of the SNS topic (topic ID)"
  value       = module.topic.topic_id
}

output "topic_arn" {
  description = "The ARN of the SNS topic"
  value       = module.topic.topic_arn
}

output "topic_name" {
  description = "The name of the SNS topic"
  value       = module.topic.topic_name
}

output "topic_owner" {
  description = "The AWS Account ID of the SNS topic owner"
  value       = module.topic.topic_owner
}

output "subscriptions" {
  description = "Map of subscriptions created and their attributes"
  value       = module.topic.subscriptions
}
