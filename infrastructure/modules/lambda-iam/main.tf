################################################################################
# Lambda Execution IAM Role Module
# IAM role with least privilege for Lambda functions
################################################################################

locals {
  role_name = "${var.project_name}-${var.environment}-lambda-execution"

  common_tags = merge(
    var.tags,
    {
      Name         = local.role_name
      Service      = "iam"
      ManagedBy    = "terraform"
      Module       = "lambda-iam"
      ResourceType = "iam-role"
    }
  )
}

################################################################################
# Lambda Execution Role
################################################################################

resource "aws_iam_role" "lambda_execution" {
  name                 = local.role_name
  description          = "Execution role for Lambda functions in ${var.project_name} ${var.environment}"
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = var.restrict_to_account ? {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        } : null
      }
    ]
  })

  tags = local.common_tags
}

################################################################################
# Basic Lambda Execution Policy (CloudWatch Logs)
################################################################################

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${local.role_name}-cloudwatch-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateLogGroup"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        Sid    = "WriteToCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-*:*"
      }
    ]
  })
}

################################################################################
# X-Ray Tracing Policy (optional)
################################################################################

resource "aws_iam_role_policy" "xray" {
  count = var.enable_xray ? 1 : 0

  name = "${local.role_name}-xray"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# VPC Access Policy (optional)
# Required for Lambda functions deployed in a VPC.
# Note: These permissions must be granted on Resource "*" as Lambda creates
# ENIs during function creation and the specific resource ARN is not known
# in advance. Security is enforced through VPC security groups.
################################################################################

resource "aws_iam_role_policy" "vpc_access" {
  count = var.enable_vpc_access ? 1 : 0

  name = "${local.role_name}-vpc-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCNetworkInterfaces"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Secrets Manager Access Policy (optional)
################################################################################

resource "aws_iam_role_policy" "secrets_manager" {
  count = length(var.secrets_arns) > 0 ? 1 : 0

  name = "${local.role_name}-secrets-manager"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_arns
      }
    ]
  })
}

################################################################################
# SSM Parameter Store Access Policy (optional)
################################################################################

resource "aws_iam_role_policy" "ssm_parameters" {
  count = length(var.ssm_parameter_arns) > 0 ? 1 : 0

  name = "${local.role_name}-ssm-parameters"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = var.ssm_parameter_arns
      }
    ]
  })
}

################################################################################
# KMS Decrypt Policy (optional)
################################################################################

resource "aws_iam_role_policy" "kms_decrypt" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  name = "${local.role_name}-kms-decrypt"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })
}

################################################################################
# S3 Access Policy (optional)
################################################################################

resource "aws_iam_role_policy" "s3_access" {
  count = length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${local.role_name}-s3-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

################################################################################
# DynamoDB Access Policy (optional)
################################################################################

resource "aws_iam_role_policy" "dynamodb_access" {
  count = length(var.dynamodb_table_arns) > 0 ? 1 : 0

  name = "${local.role_name}-dynamodb-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = concat(
          var.dynamodb_table_arns,
          [for arn in var.dynamodb_table_arns : "${arn}/index/*"]
        )
      }
    ]
  })
}

################################################################################
# SQS Access Policy (optional)
################################################################################

resource "aws_iam_role_policy" "sqs_access" {
  count = length(var.sqs_queue_arns) > 0 ? 1 : 0

  name = "${local.role_name}-sqs-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arns
      }
    ]
  })
}

################################################################################
# Custom Policy (optional)
################################################################################

resource "aws_iam_role_policy" "custom" {
  for_each = var.custom_policies

  name   = "${local.role_name}-${each.key}"
  role   = aws_iam_role.lambda_execution.id
  policy = each.value
}

################################################################################
# Managed Policy Attachments (optional)
################################################################################

resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.lambda_execution.name
  policy_arn = each.value
}
