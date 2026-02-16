# SQS Module

AWS SQS queue module with Dead Letter Queue, encryption, and CloudWatch monitoring.

## Features

- **Queue Types**: Standard or FIFO queues
- **Dead Letter Queue**: Automatic DLQ creation with configurable retry limits
- **Encryption**: KMS or SQS-managed encryption
- **Monitoring**: CloudWatch alarms for queue age, depth, and DLQ messages
- **Message Configuration**: Configurable retention, visibility timeout, and delays
- **DLQ Redrive**: Optional ability to reprocess messages from DLQ

## Usage

### Basic Standard Queue

```hcl
module "orders_queue" {
  source = "../../modules/sqs"

  project_name      = "myapp"
  environment       = "prod"
  queue_name_suffix = "orders"

  # Message configuration
  visibility_timeout_seconds = 300  # 5 minutes
  message_retention_seconds  = 345600  # 4 days

  # DLQ configuration
  create_dlq        = true
  max_receive_count = 3

  tags = {
    Owner = "platform-team"
  }
}
```

### FIFO Queue with Content-Based Deduplication

```hcl
module "notifications_fifo" {
  source = "../../modules/sqs"

  project_name      = "myapp"
  environment       = "prod"
  queue_name_suffix = "notifications"

  # FIFO configuration
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope         = "messageGroup"
  fifo_throughput_limit       = "perMessageGroupId"

  # Encryption
  kms_master_key_id = aws_kms_key.main.id

  # Alarms
  create_cloudwatch_alarms = true
  alarm_actions            = [aws_sns_topic.alerts.arn]

  tags = {
    Owner = "platform-team"
  }
}
```

### Queue with Custom Policy

```hcl
module "events_queue" {
  source = "../../modules/sqs"

  project_name      = "myapp"
  environment       = "prod"
  queue_name_suffix = "events"

  # Policy
  create_queue_policy = true
  queue_policy_statements = {
    lambda_send = {
      sid    = "AllowLambdaSend"
      effect = "Allow"
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
      actions   = ["sqs:SendMessage"]
      resources = ["*"]
      conditions = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [aws_lambda_function.processor.arn]
      }]
    }
  }

  tags = {
    Owner = "platform-team"
  }
}
```

## CloudWatch Alarms

The module creates three types of alarms:

1. **Queue Age Alarm**: Triggers when oldest message exceeds threshold (default: 10 minutes)
2. **Queue Depth Alarm**: Triggers when queue has too many messages (default: 1000)
3. **DLQ Alarm**: Triggers when DLQ receives any messages (default: 0)

Configure alarm thresholds and SNS notification targets:

```hcl
create_cloudwatch_alarms = true
alarm_actions            = [aws_sns_topic.alerts.arn]
alarm_age_threshold      = 600   # 10 minutes
alarm_depth_threshold    = 1000  # messages
alarm_dlq_threshold      = 0     # alert on any DLQ message
```

## Encryption

### SQS-Managed Encryption (Default)

```hcl
sqs_managed_sse_enabled = true
```

### KMS Encryption

```hcl
kms_master_key_id                 = aws_kms_key.main.id
kms_data_key_reuse_period_seconds = 300
sqs_managed_sse_enabled           = false
```

## Dead Letter Queue

The module automatically creates a DLQ with:

- Same encryption as main queue
- Longer retention (14 days by default)
- Automatic redrive policy configured
- Optional redrive back to source queue

Disable DLQ:

```hcl
create_dlq = false
```

## Lambda Integration

To grant Lambda permission to consume from the queue:

```hcl
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = module.orders_queue.queue_arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 10
}

# Add to Lambda IAM role
data "aws_iam_policy_document" "lambda_sqs" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [module.orders_queue.queue_arn]
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| queue_name_suffix | Suffix for queue name | `string` | `null` | no |
| fifo_queue | Enable FIFO queue | `bool` | `false` | no |
| content_based_deduplication | Enable content-based deduplication | `bool` | `false` | no |
| kms_master_key_id | KMS key ID for encryption | `string` | `null` | no |
| sqs_managed_sse_enabled | Enable SQS managed encryption | `bool` | `true` | no |
| visibility_timeout_seconds | Visibility timeout | `number` | `30` | no |
| message_retention_seconds | Message retention period | `number` | `345600` | no |
| max_message_size | Maximum message size in bytes | `number` | `262144` | no |
| delay_seconds | Delay before message available | `number` | `0` | no |
| receive_wait_time_seconds | Long polling wait time | `number` | `0` | no |
| create_dlq | Create Dead Letter Queue | `bool` | `true` | no |
| max_receive_count | Max receives before DLQ | `number` | `3` | no |
| dlq_message_retention_seconds | DLQ retention period | `number` | `1209600` | no |
| enable_dlq_redrive | Allow redrive from DLQ | `bool` | `true` | no |
| create_cloudwatch_alarms | Create CloudWatch alarms | `bool` | `true` | no |
| alarm_actions | SNS topics for alarm notifications | `list(string)` | `[]` | no |
| alarm_age_threshold | Queue age alarm threshold (seconds) | `number` | `600` | no |
| alarm_depth_threshold | Queue depth alarm threshold | `number` | `1000` | no |
| alarm_dlq_threshold | DLQ alarm threshold | `number` | `0` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| queue_id | The URL for the SQS queue |
| queue_arn | The ARN of the SQS queue |
| queue_name | The name of the SQS queue |
| queue_url | The URL of the SQS queue |
| dlq_id | The URL for the DLQ |
| dlq_arn | The ARN of the DLQ |
| dlq_name | The name of the DLQ |
| dlq_url | The URL of the DLQ |
| alarm_queue_age_arn | ARN of queue age alarm |
| alarm_queue_depth_arn | ARN of queue depth alarm |
| alarm_dlq_depth_arn | ARN of DLQ depth alarm |

## Best Practices

1. **Always use DLQ**: Enable DLQ to capture failed messages for analysis
2. **Set appropriate visibility timeout**: Should be 6x your Lambda timeout
3. **Enable encryption**: Use KMS encryption for sensitive data
4. **Configure alarms**: Set up SNS notifications for queue issues
5. **Use FIFO for ordering**: When message order matters
6. **Long polling**: Set `receive_wait_time_seconds > 0` to reduce costs
7. **Message retention**: Balance between cost and recovery needs

## Examples

See the module documentation for complete examples of:

- Standard queues
- FIFO queues with deduplication
- Lambda integration patterns
- Custom access policies
- Multi-queue architectures
