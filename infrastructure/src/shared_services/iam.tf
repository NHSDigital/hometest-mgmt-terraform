################################################################################
# Developer IAM Role (Shared across environments)
################################################################################

resource "aws_iam_role" "developer" {
  name = "${local.resource_prefix}-developer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.developer_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = var.require_mfa ? {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        } : {}
      }
    ]
  })

  max_session_duration = 3600

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-developer-role"
  })
}

resource "aws_iam_role_policy" "developer_lambda" {
  name = "lambda-deployment"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaDeployment"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-*"
      },
      # {
      #   Sid    = "S3ArtifactAccess"
      #   Effect = "Allow"
      #   Action = [
      #     "s3:GetObject",
      #     "s3:PutObject",
      #     "s3:ListBucket"
      #   ]
      #   Resource = [
      #     aws_s3_bucket.deployment_artifacts.arn,
      #     "${aws_s3_bucket.deployment_artifacts.arn}/*"
      #   ]
      # },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

################################################################################
# Developer Deployment Policy
# Customer-managed policy for SSO Permission Set attachment
# Allows developers to deploy/update their environment's resources
################################################################################

resource "aws_iam_policy" "developer_deployment" {
  name        = "${local.resource_prefix}-developer-deployment"
  description = "Deployment permissions for HomeTest developers via SSO"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda deployment
      {
        Sid    = "LambdaDeployment"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias"
        ]
        Resource = "arn:aws:lambda:*:*:function:${var.project_name}-*"
      },
      # API Gateway deployment
      {
        Sid    = "APIGatewayDeployment"
        Effect = "Allow"
        Action = [
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH"
        ]
        Resource = [
          "arn:aws:apigateway:*::/restapis/*/deployments",
          "arn:aws:apigateway:*::/restapis/*/deployments/*",
          "arn:aws:apigateway:*::/restapis/*/stages/*"
        ]
      },
      # CloudFront cache invalidation
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = "*"
      },
      # S3 deployment access
      {
        Sid    = "S3DeploymentAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      },
      # S3 Terraform state access
      {
        Sid    = "S3TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate",
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate/*"
        ]
      },
      # SQS queue management
      {
        Sid    = "SQSQueueManagement"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:DeleteMessage",
          "sqs:PurgeQueue"
        ]
        Resource = "arn:aws:sqs:*:*:${var.project_name}-*"
      },
      # KMS encryption/decryption
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:*:${var.aws_account_id}:key/*"
        Condition = {
          StringLike = {
            "kms:ResourceAliases" = "alias/${var.project_name}-*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-developer-deployment"
  })
}

################################################################################
# ReadOnly Terraform State Access Policy
# Customer-managed policy for SSO ReadOnly Permission Set attachment
# Allows read-only users to decrypt terraform state files
################################################################################

resource "aws_iam_policy" "tfstate_readonly" {
  name        = "${local.resource_prefix}-tfstate-readonly"
  description = "Read-only access to Terraform state for SSO ReadOnly users"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Terraform state read access
      {
        Sid    = "S3TerraformStateReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate",
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate/*"
        ]
      },
      # KMS decryption for state files
      {
        Sid    = "KMSDecryptTerraformState"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:*:${var.aws_account_id}:key/*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "kms:ResourceAliases" = "alias/${var.project_name}-*-kms-tfstate-key"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate-readonly"
  })
}
