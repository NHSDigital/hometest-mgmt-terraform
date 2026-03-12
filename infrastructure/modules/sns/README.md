# SNS Module

AWS SNS topic module with optional encryption and subscription support.

## Features

- **Topic Types**: Standard or FIFO topics
- **Naming Convention**: `<project>-<environment>-<topic_name_suffix>`
- **Encryption**: Optional KMS encryption for SNS topics
- **Policies**: Support for default and custom topic policies
- **Subscriptions**: Configurable subscriptions (SQS, Lambda, HTTP/S, email, etc.)

## Usage

### Basic Topic

```hcl
module "alerts_topic" {
  source = "../../modules/sns"

  project_name      = "myapp"
  environment       = "prod"
  topic_name_suffix = "alerts"

  tags = {
    Owner = "platform-team"
  }
}
```

### Topic with Subscriptions

```hcl
module "notifications_topic" {
  source = "../../modules/sns"

  project_name      = "myapp"
  environment       = "prod"
  topic_name_suffix = "notifications"

  # Example SQS subscription
  subscriptions = {
    sqs = {
      protocol = "sqs"
      endpoint = module.notifications_queue.queue_arn
    }
  }

  tags = {
    Owner = "platform-team"
  }
}
```

### FIFO Topic

```hcl
module "fifo_topic" {
  source = "../../modules/sns"

  project_name      = "myapp"
  environment       = "prod"
  topic_name_suffix = "events"

  fifo_topic                  = true
  content_based_deduplication = true
  fifo_throughput_scope       = "Topic"

  tags = {
    Owner = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| topic_name_suffix | Suffix for topic name | `string` | `null` | no |
| display_name | Display name for the SNS topic | `string` | `null` | no |
| fifo_topic | Enable FIFO topic | `bool` | `false` | no |
| content_based_deduplication | Enable content-based deduplication | `bool` | `false` | no |
| fifo_throughput_scope | FIFO throughput scope (Topic or MessageGroup) | `string` | `null` | no |
| kms_master_key_id | KMS key ID for encryption | `string` | `null` | no |
| create_topic_policy | Create an SNS topic policy | `bool` | `true` | no |
| enable_default_topic_policy | Enable default SNS topic policy | `bool` | `true` | no |
| topic_policy_statements | IAM policy statements for topic access | `any` | `null` | no |
| topic_policy | Fully-formed topic policy JSON | `string` | `null` | no |
| create_subscription | Create SNS subscriptions | `bool` | `true` | no |
| subscriptions | Map of SNS subscriptions to create | `any` | `{}` | no |
| delivery_policy | SNS delivery policy JSON | `string` | `null` | no |
| data_protection_policy | Data protection policy JSON | `string` | `null` | no |
| tracing_config | Tracing configuration (PassThrough or Active) | `string` | `null` | no |
| signature_version | Signature version (1 or 2) | `number` | `null` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| topic_id | ARN of the SNS topic (topic ID) |
| topic_arn | ARN of the SNS topic |
| topic_name | Name of the SNS topic |
| topic_owner | AWS Account ID of the topic owner |
| subscriptions | Map of subscriptions and their attributes |

## Best Practices

1. Use KMS encryption for topics carrying sensitive data.
2. Use explicit topic policies to restrict who can publish and subscribe.
3. Prefer SQS subscriptions for decoupled, durable consumers.
4. Use FIFO topics when order and exactly-once processing are required.
5. Reuse naming conventions across projects for consistency.
