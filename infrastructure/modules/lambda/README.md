# Lambda Module

Terraform module for deploying AWS Lambda functions with security best practices.

## Features

- **Security First**: KMS encryption for environment variables and CloudWatch logs
- **Observability**: X-Ray tracing enabled by default
- **Monitoring**: Optional CloudWatch alarm for Lambda errors (failed invocations)
- **VPC Support**: Optional VPC configuration for private resources
- **Dead Letter Queue**: Failed invocations can be sent to SQS/SNS
- **Function URL**: Optional direct HTTPS endpoint
- **Aliases**: Support for traffic shifting and blue/green deployments

## Usage

```hcl
module "my_lambda" {
  source = "../../modules/lambda"

  project_name    = "nhs-hometest"
  function_name   = "my-function"
  environment     = "dev"
  lambda_role_arn = aws_iam_role.lambda_execution.arn

  s3_bucket = "my-deployment-bucket"
  s3_key    = "lambdas/my-function.zip"

  environment_variables = {
    API_URL = "https://api.example.com"
  }

  # Optional VPC configuration
  vpc_subnet_ids         = module.vpc.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.lambda.id]

  # Optional encryption
  lambda_kms_key_arn     = aws_kms_key.lambda.arn
  cloudwatch_kms_key_arn = aws_kms_key.cloudwatch.arn

  tags = {
    Owner       = "platform-team"
    Environment = "dev"
  }
}
```

## Security Best Practices

1. **Environment Variable Encryption**: Use `lambda_kms_key_arn` to encrypt sensitive environment variables
2. **Log Encryption**: Use `cloudwatch_kms_key_arn` to encrypt CloudWatch logs
3. **VPC Isolation**: Deploy in VPC with private subnets for accessing internal resources
4. **X-Ray Tracing**: Enabled by default for distributed tracing
5. **Dead Letter Queue**: Configure DLQ to capture failed invocations
6. **Least Privilege**: Ensure the Lambda execution role follows least privilege principle

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| function_name | Name of the Lambda function | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| lambda_role_arn | ARN of the IAM role | `string` | n/a | yes |
| s3_bucket | S3 bucket for deployment package | `string` | n/a | yes |
| s3_key | S3 key for deployment package | `string` | n/a | yes |
| runtime | Lambda runtime | `string` | `"nodejs20.x"` | no |
| timeout | Function timeout (seconds) | `number` | `30` | no |
| memory_size | Function memory (MB) | `number` | `256` | no |
| create_cloudwatch_alarms | Create CloudWatch alarms for Lambda errors | `bool` | `true` | no |
| alarm_actions | ARNs notified when the alarm triggers (e.g., SNS topics) | `list(string)` | `[]` | no |
| alarm_period | Period over which to evaluate the error metric (seconds) | `number` | `300` | no |
| alarm_evaluation_periods | Number of periods over which to evaluate the alarm | `number` | `1` | no |
| alarm_error_threshold | Threshold for Lambda error alarm (errors per period) | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| function_invoke_arn | Invoke ARN for API Gateway integration |
| log_group_name | CloudWatch log group name |
| error_alarm_arn | ARN of the Lambda errors CloudWatch alarm (if created) |
