################################################################################
# IAM Developer Role - Scoped to Environment
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "iam-developer-role"
  })

  role_name = "${local.resource_prefix}-developer-role"

  # Resource pattern for environment-scoped resources
  env_resource_pattern = "${var.project_name}-${var.aws_account_shortname}-${var.environment}*"
}

################################################################################
# IAM Role for Developers
################################################################################

resource "aws_iam_role" "developer" {
  name        = local.role_name
  description = "Developer role for ${local.resource_prefix} environment with scoped permissions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # AWS SSO / Identity Center trust
      var.enable_sso_trust ? [
        {
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = "sts:AssumeRole"
          Condition = {
            StringEquals = {
              "aws:PrincipalTag/Team" = var.allowed_teams
            }
          }
        }
      ] : [],
      # AWS AFT trust (for future Account Factory for Terraform integration)
      var.enable_aft_trust ? [
        {
          Effect = "Allow"
          Principal = {
            AWS = var.aft_management_account_id != "" ? "arn:aws:iam::${var.aft_management_account_id}:root" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = "sts:AssumeRole"
          Condition = {
            StringEquals = {
              "sts:ExternalId" = var.aft_external_id
            }
          }
        }
      ] : [],
      # GitHub OIDC trust (for CI/CD)
      var.enable_github_oidc_trust ? [
        {
          Effect = "Allow"
          Principal = {
            Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
            }
          }
        }
      ] : [],
      # Fallback: Allow assume from account root (for testing)
      var.enable_account_trust ? [
        {
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = "sts:AssumeRole"
        }
      ] : []
    )
  })

  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, {
    Name            = local.role_name
    Environment     = var.environment
    AFTReady        = var.enable_aft_trust ? "true" : "false"
    PermissionScope = "environment-scoped"
  })
}

################################################################################
# Lambda Permissions - Deploy and Update
################################################################################

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.resource_prefix}-developer-lambda"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaReadAll"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetAlias",
          "lambda:GetPolicy",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
          "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:*"
      },
      {
        Sid    = "LambdaManageEnvScoped"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.env_resource_pattern}"
      },
      {
        Sid      = "LambdaPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.env_resource_pattern}"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      }
    ]
  })
}

################################################################################
# API Gateway Permissions
################################################################################

resource "aws_iam_role_policy" "api_gateway_permissions" {
  name = "${local.resource_prefix}-developer-apigateway"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "APIGatewayReadAll"
        Effect = "Allow"
        Action = [
          "apigateway:GET"
        ]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*",
          "arn:aws:apigateway:${var.aws_region}::/apis",
          "arn:aws:apigateway:${var.aws_region}::/apis/*"
        ]
      },
      {
        Sid    = "APIGatewayManageEnvScoped"
        Effect = "Allow"
        Action = [
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE"
        ]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis/*",
          "arn:aws:apigateway:${var.aws_region}::/apis/*"
        ]
        Condition = {
          StringLike = {
            "apigateway:Request/Name" = local.env_resource_pattern
          }
        }
      }
    ]
  })
}

################################################################################
# CloudWatch Logs Permissions - Read Only
################################################################################

resource "aws_iam_role_policy" "cloudwatch_logs_permissions" {
  name = "${local.resource_prefix}-developer-logs"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsReadEnvScoped"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetLogRecord",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:DescribeQueries",
          "logs:GetLogDelivery",
          "logs:ListLogDeliveries"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.env_resource_pattern}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.env_resource_pattern}:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/${local.env_resource_pattern}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/${local.env_resource_pattern}:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.env_resource_pattern}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.env_resource_pattern}:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsInsightsQuery"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# CloudWatch Metrics Permissions
################################################################################

resource "aws_iam_role_policy" "cloudwatch_metrics_permissions" {
  name = "${local.resource_prefix}-developer-metrics"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetricsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarmsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmHistory"
        ]
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:*"
      },
      {
        Sid    = "CloudWatchDashboardsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/*"
      }
    ]
  })
}

################################################################################
# X-Ray Permissions
################################################################################

resource "aws_iam_role_policy" "xray_permissions" {
  name = "${local.resource_prefix}-developer-xray"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayReadSampling"
        Effect = "Allow"
        Action = [
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      },
      {
        Sid    = "XRayReadTraces"
        Effect = "Allow"
        Action = [
          "xray:BatchGetTraces",
          "xray:GetServiceGraph",
          "xray:GetTraceGraph",
          "xray:GetTraceSummaries",
          "xray:GetTimeSeriesServiceStatistics"
        ]
        Resource = [
          "arn:aws:xray:${var.aws_region}:${data.aws_caller_identity.current.account_id}:group/*",
          "*"
        ]
      },
      {
        Sid    = "XRayReadGroups"
        Effect = "Allow"
        Action = [
          "xray:GetGroups",
          "xray:GetGroup"
        ]
        Resource = "arn:aws:xray:${var.aws_region}:${data.aws_caller_identity.current.account_id}:group/*"
      },
      {
        Sid    = "XRayReadInsights"
        Effect = "Allow"
        Action = [
          "xray:GetInsightSummaries",
          "xray:GetInsight",
          "xray:GetInsightEvents",
          "xray:GetInsightImpactGraph"
        ]
        Resource = "arn:aws:xray:${var.aws_region}:${data.aws_caller_identity.current.account_id}:insight/*"
      }
    ]
  })
}

################################################################################
# S3 Permissions - Artifacts Bucket Only
################################################################################

resource "aws_iam_role_policy" "s3_permissions" {
  name = "${local.resource_prefix}-developer-s3"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::${local.resource_prefix}-lambda-artifacts",
          "arn:aws:s3:::${local.resource_prefix}-lambda-artifacts/*"
        ]
      }
    ]
  })
}

################################################################################
# KMS Permissions - Environment Keys Only
################################################################################

resource "aws_iam_role_policy" "kms_permissions" {
  name = "${local.resource_prefix}-developer-kms"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSEnvScopedKeys"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${local.env_resource_pattern}"
      },
      {
        Sid    = "KMSListKeys"
        Effect = "Allow"
        Action = [
          "kms:ListKeys",
          "kms:ListAliases"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# CloudTrail Permissions - Read Only
################################################################################

resource "aws_iam_role_policy" "cloudtrail_permissions" {
  name = "${local.resource_prefix}-developer-cloudtrail"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudTrailReadTrails"
        Effect = "Allow"
        Action = [
          "cloudtrail:GetEventSelectors",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTrails"
        ]
        Resource = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/*"
      },
      {
        Sid    = "CloudTrailLookupEvents"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# IAM Read Permissions (for troubleshooting)
################################################################################

resource "aws_iam_role_policy" "iam_read_permissions" {
  name = "${local.resource_prefix}-developer-iam-read"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMReadEnvScoped"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.env_resource_pattern}",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.env_resource_pattern}"
        ]
      }
    ]
  })
}

################################################################################
# Additional Custom Permissions
################################################################################

resource "aws_iam_role_policy" "custom_permissions" {
  count = length(var.additional_iam_statements) > 0 ? 1 : 0

  name = "${local.resource_prefix}-developer-custom"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.additional_iam_statements
  })
}
