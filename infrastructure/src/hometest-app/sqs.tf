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

  name                       = "${local.resource_prefix}-order-results"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-order-results"
  })
}

################################################################################
# SQS Queue for Event Processing (triggers lambdas)
################################################################################

resource "aws_sqs_queue" "main" {
  count = length(local.sqs_lambdas) > 0 ? 1 : 0

  name                       = "${local.resource_prefix}-events"
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
    Name = "${local.resource_prefix}-events"
  })
}

################################################################################
# Dead Letter Queue for Failed Messages
################################################################################

resource "aws_sqs_queue" "dlq" {
  count = length(local.sqs_lambdas) > 0 ? 1 : 0

  name                       = "${local.resource_prefix}-events-dlq"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  # Enable server-side encryption with KMS
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-events-dlq"
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
            "aws:SourceArn" = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${local.resource_prefix}-*"
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
