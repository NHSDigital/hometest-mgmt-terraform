################################################################################
# SQS Module Outputs
################################################################################

#------------------------------------------------------------------------------
# Queue Outputs
#------------------------------------------------------------------------------

output "queue_id" {
  description = "The URL for the created SQS queue"
  value       = module.queue.queue_id
}

output "queue_arn" {
  description = "The ARN of the SQS queue"
  value       = module.queue.queue_arn
}

output "queue_name" {
  description = "The name of the SQS queue"
  value       = module.queue.queue_name
}

output "queue_url" {
  description = "The URL of the SQS queue"
  value       = module.queue.queue_url
}

#------------------------------------------------------------------------------
# Dead Letter Queue Outputs
#------------------------------------------------------------------------------

output "dlq_id" {
  description = "The URL for the created DLQ"
  value       = var.create_dlq ? module.dlq[0].queue_id : null
}

output "dlq_arn" {
  description = "The ARN of the DLQ"
  value       = var.create_dlq ? module.dlq[0].queue_arn : null
}

output "dlq_name" {
  description = "The name of the DLQ"
  value       = var.create_dlq ? module.dlq[0].queue_name : null
}

output "dlq_url" {
  description = "The URL of the DLQ"
  value       = var.create_dlq ? module.dlq[0].queue_url : null
}

#------------------------------------------------------------------------------
# CloudWatch Alarm Outputs
#------------------------------------------------------------------------------

output "alarm_queue_age_arn" {
  description = "ARN of the queue age CloudWatch alarm"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.queue_age[0].arn : null
}

output "alarm_queue_depth_arn" {
  description = "ARN of the queue depth CloudWatch alarm"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.queue_depth[0].arn : null
}

output "alarm_dlq_depth_arn" {
  description = "ARN of the DLQ depth CloudWatch alarm"
  value       = var.create_dlq && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.dlq_depth[0].arn : null
}
