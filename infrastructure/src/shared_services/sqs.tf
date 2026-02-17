################################################################################
# SQS Queues
# Shared queues for the hometest application
################################################################################

#------------------------------------------------------------------------------
# Orders Queue
# For processing test kit orders
#------------------------------------------------------------------------------

module "sqs_orders" {
  source = "../../modules/sqs"

  project_name      = var.project_name
  environment       = var.environment
  queue_name_suffix = "orders-results"

  # Message configuration
  visibility_timeout_seconds = var.orders_queue_visibility_timeout
  message_retention_seconds  = var.orders_queue_retention_seconds
  receive_wait_time_seconds  = 10 # Enable long polling

  # DLQ configuration
  create_dlq        = true
  max_receive_count = var.orders_queue_max_receive_count

  # Encryption
  kms_master_key_id       = aws_kms_key.main.id
  sqs_managed_sse_enabled = false

  # CloudWatch alarms
  create_cloudwatch_alarms = var.create_sqs_alarms
  alarm_actions            = length(var.sqs_alarm_sns_topics) > 0 ? var.sqs_alarm_sns_topics : [module.sns_alerts.topic_arn]
  alarm_age_threshold      = var.orders_queue_age_threshold
  alarm_depth_threshold    = var.orders_queue_depth_threshold

  # Resource group
  create_resource_group = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Notifications Queue (FIFO)
# For reliable, ordered notification delivery
#------------------------------------------------------------------------------

module "sqs_notifications" {
  source = "../../modules/sqs"

  project_name      = var.project_name
  environment       = var.environment
  queue_name_suffix = "notifications"

  # FIFO configuration
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope         = "messageGroup"
  fifo_throughput_limit       = "perMessageGroupId"

  # Message configuration
  visibility_timeout_seconds = var.notifications_queue_visibility_timeout
  message_retention_seconds  = var.notifications_queue_retention_seconds
  receive_wait_time_seconds  = 10

  # DLQ configuration
  create_dlq        = true
  max_receive_count = var.notifications_queue_max_receive_count

  # Encryption
  kms_master_key_id       = aws_kms_key.main.id
  sqs_managed_sse_enabled = false

  # CloudWatch alarms
  create_cloudwatch_alarms = var.create_sqs_alarms
  alarm_actions            = length(var.sqs_alarm_sns_topics) > 0 ? var.sqs_alarm_sns_topics : [module.sns_alerts.topic_arn]
  alarm_age_threshold      = var.notifications_queue_age_threshold
  alarm_depth_threshold    = var.notifications_queue_depth_threshold

  # Resource group
  create_resource_group = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Events Queue
# For application events and audit logging
#------------------------------------------------------------------------------

module "sqs_events" {
  source = "../../modules/sqs"

  project_name      = var.project_name
  environment       = var.environment
  queue_name_suffix = "events"

  # Message configuration
  visibility_timeout_seconds = var.events_queue_visibility_timeout
  message_retention_seconds  = var.events_queue_retention_seconds
  receive_wait_time_seconds  = 10

  # DLQ configuration
  create_dlq        = true
  max_receive_count = var.events_queue_max_receive_count

  # Encryption
  kms_master_key_id       = aws_kms_key.main.id
  sqs_managed_sse_enabled = false

  # CloudWatch alarms
  create_cloudwatch_alarms = var.create_sqs_alarms
  alarm_actions            = length(var.sqs_alarm_sns_topics) > 0 ? var.sqs_alarm_sns_topics : [module.sns_alerts.topic_arn]
  alarm_age_threshold      = var.events_queue_age_threshold
  alarm_depth_threshold    = var.events_queue_depth_threshold

  # Resource group
  create_resource_group = true

  tags = local.common_tags
}
