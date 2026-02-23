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
# Developer Deployment Policies
# Customer-managed policies for SSO Permission Set attachment
# Allows developers to deploy/destroy hometest-app environments with Terragrunt
#
# Split into 3 policies to stay under AWS 6,144 char managed policy limit:
#   1. developer_deployment       - IAM, Lambda, API Gateway, SQS
#   2. developer_deployment_cdn   - CloudFront, S3, Route53
#   3. developer_deployment_infra - CloudWatch, KMS, EC2, WAF, ACM, SNS,
#                                   Resource Groups, TF state
################################################################################

# Policy 1: Compute & API (IAM, Lambda, API Gateway, SQS)
resource "aws_iam_policy" "developer_deployment" {
  name        = "${local.resource_prefix}-developer-deployment"
  description = "Deployment permissions for HomeTest developers via SSO"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMRoleMgmt"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-*"
      },
      {
        Sid    = "LambdaMgmt"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:ListTags",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:GetAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:CreateFunctionUrlConfig",
          "lambda:UpdateFunctionUrlConfig",
          "lambda:DeleteFunctionUrlConfig",
          "lambda:GetFunctionUrlConfig"
        ]
        Resource = "arn:aws:lambda:*:${var.aws_account_id}:function:${var.project_name}-*"
      },
      {
        Sid    = "LambdaESM"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping",
          "lambda:ListEventSourceMappings"
        ]
        Resource = "*"
      },
      {
        Sid    = "APIGatewayMgmt"
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE"
        ]
        Resource = [
          "arn:aws:apigateway:*::/restapis",
          "arn:aws:apigateway:*::/restapis/*",
          "arn:aws:apigateway:*::/tags/*"
        ]
      },
      {
        Sid      = "APIGatewayAcct"
        Effect   = "Allow"
        Action   = ["apigateway:GET", "apigateway:PATCH"]
        Resource = "arn:aws:apigateway:*::/account"
      },
      {
        Sid    = "SQSMgmt"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags",
          "sqs:SendMessage",
          "sqs:DeleteMessage",
          "sqs:PurgeQueue",
          "sqs:AddPermission",
          "sqs:RemovePermission"
        ]
        Resource = "arn:aws:sqs:*:${var.aws_account_id}:${var.project_name}-*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-developer-deployment"
  })
}

# Policy 2: CDN & Storage (CloudFront, S3, Route53)
resource "aws_iam_policy" "developer_deployment_cdn" {
  name        = "${local.resource_prefix}-developer-deployment-cdn"
  description = "Developer deploy permissions: CloudFront, S3, Route53"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontMgmt"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateResponseHeadersPolicy",
          "cloudfront:UpdateResponseHeadersPolicy",
          "cloudfront:DeleteResponseHeadersPolicy",
          "cloudfront:GetResponseHeadersPolicy",
          "cloudfront:CreateCachePolicy",
          "cloudfront:UpdateCachePolicy",
          "cloudfront:DeleteCachePolicy",
          "cloudfront:GetCachePolicy",
          "cloudfront:CreateFunction",
          "cloudfront:UpdateFunction",
          "cloudfront:DeleteFunction",
          "cloudfront:GetFunction",
          "cloudfront:DescribeFunction",
          "cloudfront:PublishFunction",
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3BucketMgmt"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLogging",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketWebsite",
          "s3:GetReplicationConfiguration",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*"
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:GetObjectVersion",
          "s3:ListBucketVersions"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      },
      {
        Sid    = "Route53Mgmt"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-developer-deployment-cdn"
  })
}

# Policy 3: Infra & Monitoring (CloudWatch, KMS, EC2, WAF, ACM, SNS, Resource Groups, TF state)
resource "aws_iam_policy" "developer_deployment_infra" {
  name        = "${local.resource_prefix}-developer-deployment-infra"
  description = "Developer deploy permissions: CloudWatch, KMS, EC2, WAF, ACM, SNS, Resource Groups, TF state"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CWLogsMgmt"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource",
          "logs:TagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies"
        ]
        Resource = [
          "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-*",
          "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-*:*",
          "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/apigateway/${var.project_name}-*",
          "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/apigateway/${var.project_name}-*:*"
        ]
      },
      {
        Sid    = "CWAlarmsMgmt"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = "arn:aws:cloudwatch:*:${var.aws_account_id}:alarm:${var.project_name}-*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
        ]
        Resource = "arn:aws:kms:*:${var.aws_account_id}:key/*"
        Condition = {
          StringLike = {
            "kms:ResourceAliases" = "alias/${var.project_name}-*"
          }
        }
      },
      {
        Sid    = "ResourceGroupMgmt"
        Effect = "Allow"
        Action = [
          "resource-groups:CreateGroup",
          "resource-groups:DeleteGroup",
          "resource-groups:GetGroup",
          "resource-groups:GetGroupQuery",
          "resource-groups:UpdateGroup",
          "resource-groups:UpdateGroupQuery",
          "resource-groups:GetTags",
          "resource-groups:Tag",
          "resource-groups:Untag",
          "resource-groups:ListGroupResources"
        ]
        Resource = "arn:aws:resource-groups:*:${var.aws_account_id}:group/${var.project_name}-*"
      },
      {
        Sid      = "EC2Describe"
        Effect   = "Allow"
        Action   = ["ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeNetworkInterfaces"]
        Resource = "*"
      },
      {
        Sid      = "WAFAssoc"
        Effect   = "Allow"
        Action   = ["wafv2:AssociateWebACL", "wafv2:DisassociateWebACL", "wafv2:GetWebACLForResource", "wafv2:GetWebACL"]
        Resource = "*"
      },
      {
        Sid      = "ACMRead"
        Effect   = "Allow"
        Action   = ["acm:DescribeCertificate", "acm:ListTagsForCertificate"]
        Resource = "arn:aws:acm:*:${var.aws_account_id}:certificate/*"
      },
      {
        Sid      = "SNSRead"
        Effect   = "Allow"
        Action   = ["sns:GetTopicAttributes", "sns:ListTagsForResource"]
        Resource = "arn:aws:sns:*:${var.aws_account_id}:${var.project_name}-*"
      },
      {
        Sid    = "TFStateAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate",
          "arn:aws:s3:::${var.project_name}-*-s3-tfstate/*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-developer-deployment-infra"
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
      # KMS decryption for state files (encrypted with the shared-services KMS key)
      {
        Sid    = "KMSDecryptTerraformState"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
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
