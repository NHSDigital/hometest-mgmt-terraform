################################################################################
# SQS Queue and Lambda Event Source Mapping
################################################################################

locals {
  # Find lambdas that need SQS triggers
  sqs_lambdas = { for k, v in local.all_lambdas : k => v if try(v.sqs_trigger, false) }
}

################################################################################
# SQS Queue for Order Results (written to by order-result-lambda)
################################################################################

resource "aws_sqs_queue" "order_results" {
  count = var.enable_sqs_access ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-order-results"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-order-results"
  })
}

################################################################################
# SQS Queue for Order Placement (triggers order-router-lambda)
################################################################################

resource "aws_sqs_queue" "order_placement" {
  count = var.enable_sqs_access ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-order-placement"
  visibility_timeout_seconds = 360     # Should be 6x Lambda timeout (60s)
  message_retention_seconds  = 1209600 # 14 days
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  # Enable dead letter queue for failed order processing
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_placement_dlq[0].arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-order-placement"
  })
}

################################################################################
# Dead Letter Queue for Order Placement Failed Messages
################################################################################

resource "aws_sqs_queue" "order_placement_dlq" {
  count = var.enable_sqs_access ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-order-placement-dlq"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-order-placement-dlq"
  })
}

################################################################################
# SQS Queue for Event Processing (triggers lambdas)
################################################################################

resource "aws_sqs_queue" "main" {
  count = length(local.sqs_lambdas) > 0 ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-events"
  visibility_timeout_seconds = 300     # Should be 6x the Lambda timeout
  message_retention_seconds  = 1209600 # 14 days
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  # Enable dead letter queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-events"
  })
}

################################################################################
# Dead Letter Queue for Failed Messages
################################################################################

resource "aws_sqs_queue" "dlq" {
  count = length(local.sqs_lambdas) > 0 ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-events-dlq"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-events-dlq"
  })
}

################################################################################
# SQS Queue Policy - Allow Lambda to receive messages
################################################################################

resource "aws_sqs_queue_policy" "main" {
  count = length(local.sqs_lambdas) > 0 ? 1 : 0

  queue_url = aws_sqs_queue.main[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaToReceive"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main[0].arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-${var.environment}-*"
          }
        }
      }
    ]
  })
}

################################################################################
# Lambda Event Source Mapping for SQS
################################################################################

resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = local.sqs_lambdas

  event_source_arn = aws_sqs_queue.main[0].arn
  function_name    = module.lambdas[each.key].function_arn
  enabled          = true

  batch_size                         = 10
  maximum_batching_window_in_seconds = 5

  # Enable partial batch failure reporting
  function_response_types = ["ReportBatchItemFailures"]

  # Scaling configuration
  scaling_config {
    maximum_concurrency = 10
  }
}

################################################################################
# Lambda Event Source Mapping for Order Placement Queue -> Order Router Lambda
################################################################################

resource "aws_lambda_event_source_mapping" "order_placement" {
  count = var.enable_sqs_access && contains(keys(local.all_lambdas), "order-router-lambda") ? 1 : 0

  event_source_arn = aws_sqs_queue.order_placement[0].arn
  function_name    = module.lambdas["order-router-lambda"].function_arn
  enabled          = true

  batch_size                         = 1
  maximum_batching_window_in_seconds = 0

  # Enable partial batch failure reporting
  function_response_types = ["ReportBatchItemFailures"]

  # Scaling configuration
  scaling_config {
    maximum_concurrency = 10
  }
}

################################################################################
# Outputs
################################################################################

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = length(local.sqs_lambdas) > 0 ? aws_sqs_queue.main[0].url : null
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = length(local.sqs_lambdas) > 0 ? aws_sqs_queue.main[0].arn : null
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = length(local.sqs_lambdas) > 0 ? aws_sqs_queue.dlq[0].url : null
}

output "sqs_dlq_arn" {
  description = "ARN of the SQS dead letter queue"
  value       = length(local.sqs_lambdas) > 0 ? aws_sqs_queue.dlq[0].arn : null
}

output "order_results_queue_url" {
  description = "URL of the order results SQS queue"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_results[0].url : null
}

output "order_results_queue_arn" {
  description = "ARN of the order results SQS queue"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_results[0].arn : null
}

output "order_placement_queue_url" {
  description = "URL of the order placement SQS queue"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_placement[0].url : null
}

output "order_placement_queue_arn" {
  description = "ARN of the order placement SQS queue"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_placement[0].arn : null
}

output "order_placement_dlq_url" {
  description = "URL of the order placement DLQ"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_placement_dlq[0].url : null
}

output "order_placement_dlq_arn" {
  description = "ARN of the order placement DLQ"
  value       = var.enable_sqs_access ? aws_sqs_queue.order_placement_dlq[0].arn : null
}
