################################################################################
# Developer Deployment IAM Role Module
# IAM role for developers to deploy Lambda and SPA from their accounts
################################################################################

locals {
  role_name = "${var.project_name}-${var.environment}-developer-deploy"

  common_tags = merge(
    var.tags,
    {
      Name         = local.role_name
      Service      = "iam"
      ManagedBy    = "terraform"
      Module       = "developer-iam"
      ResourceType = "iam-role"
      Purpose      = "developer-deployment"
    }
  )
}

################################################################################
# Developer Deployment Role
################################################################################

resource "aws_iam_role" "developer_deploy" {
  name                 = local.role_name
  description          = "Role for developers to deploy ${var.project_name} in ${var.environment}"
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDeveloperAccounts"
        Effect = "Allow"
        Principal = {
          AWS = var.developer_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = var.require_mfa ? "true" : null
          }
          StringEquals = var.require_external_id ? {
            "sts:ExternalId" = var.external_id
          } : null
          IpAddress = length(var.allowed_ip_ranges) > 0 ? {
            "aws:SourceIp" = var.allowed_ip_ranges
          } : null
        }
      }
    ]
  })

  tags = local.common_tags
}

################################################################################
# Lambda Deployment Policy
################################################################################

resource "aws_iam_role_policy" "lambda_deploy" {
  name = "${local.role_name}-lambda-deploy"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaRead"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
          "lambda:GetAlias"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-${var.environment}-*"
      },
      {
        Sid    = "LambdaUpdate"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:CreateAlias"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-${var.environment}-*"
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-${var.environment}-*"
        Condition = {
          StringEquals = {
            "lambda:FunctionUrlAuthType" = "AWS_IAM"
          }
        }
      }
    ]
  })
}

################################################################################
# S3 SPA Deployment Policy
################################################################################

resource "aws_iam_role_policy" "s3_spa_deploy" {
  name = "${local.role_name}-s3-spa-deploy"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-spa-${var.aws_account_id}"
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-spa-${var.aws_account_id}/*"
      }
    ]
  })
}

################################################################################
# S3 Lambda Artifacts Deployment Policy
################################################################################

resource "aws_iam_role_policy" "s3_lambda_artifacts" {
  name = "${local.role_name}-s3-lambda-artifacts"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactsBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts-${var.aws_account_id}"
      },
      {
        Sid    = "S3ArtifactsObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts-${var.aws_account_id}/*"
      }
    ]
  })
}

################################################################################
# CloudFront Invalidation Policy
################################################################################

resource "aws_iam_role_policy" "cloudfront_invalidation" {
  name = "${local.role_name}-cloudfront-invalidation"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = var.cloudfront_distribution_arn != null ? var.cloudfront_distribution_arn : "arn:aws:cloudfront::${var.aws_account_id}:distribution/*"
      },
      {
        Sid    = "CloudFrontRead"
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig"
        ]
        Resource = var.cloudfront_distribution_arn != null ? var.cloudfront_distribution_arn : "arn:aws:cloudfront::${var.aws_account_id}:distribution/*"
      }
    ]
  })
}

################################################################################
# CloudWatch Logs Read Policy (for debugging)
################################################################################

resource "aws_iam_role_policy" "cloudwatch_logs_read" {
  name = "${local.role_name}-cloudwatch-logs-read"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-*:*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/api-gateway/${var.project_name}-${var.environment}-*:*"
        ]
      }
    ]
  })
}

################################################################################
# KMS Policy (if encryption is used)
################################################################################

resource "aws_iam_role_policy" "kms_access" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  name = "${local.role_name}-kms-access"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSEncryptDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })
}

################################################################################
# API Gateway Read Policy (for debugging)
################################################################################

resource "aws_iam_role_policy" "api_gateway_read" {
  name = "${local.role_name}-api-gateway-read"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "APIGatewayRead"
        Effect = "Allow"
        Action = [
          "apigateway:GET"
        ]
        Resource = "arn:aws:apigateway:${var.aws_region}::/restapis/*"
      }
    ]
  })
}

################################################################################
# Deny Dangerous Actions
################################################################################

resource "aws_iam_role_policy" "deny_dangerous_actions" {
  name = "${local.role_name}-deny-dangerous"
  role = aws_iam_role.developer_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMChanges"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDeleteBuckets"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteBucketPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDeleteLambda"
        Effect = "Deny"
        Action = [
          "lambda:DeleteFunction"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyCloudTrailChanges"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      }
    ]
  })
}
