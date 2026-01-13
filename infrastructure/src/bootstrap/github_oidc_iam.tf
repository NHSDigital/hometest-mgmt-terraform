################################################################################
# GitHub OIDC Provider (Account-level, create once)
################################################################################

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # GitHub OIDC thumbprints
  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(local.common_tags, {
    Name = "github-oidc-provider"
  })
}

################################################################################
# IAM Role for GitHub Actions (with strict OIDC conditions)
################################################################################

# Build the list of allowed subjects for the trust policy
locals {
  # Allow all branches wildcard
  all_branches_subject = ["repo:${var.github_repo}:*"]

  # Allow specific branches
  branch_subjects = [for branch in var.github_branches : "repo:${var.github_repo}:ref:refs/heads/${branch}"]

  # Allow specific environments
  environment_subjects = [for env in var.github_environments : "repo:${var.github_repo}:environment:${env}"]

  # Allow pull requests (for plan only - consider separate role for PRs)
  pr_subjects = ["repo:${var.github_repo}:pull_request"]

  # Combine all allowed subjects based on flag
  # If github_allow_all_branches is true, allow all branches from the repo
  # Otherwise, restrict to specific branches and environments
  all_allowed_subjects = var.github_allow_all_branches ? local.all_branches_subject : concat(
    local.branch_subjects,
    local.environment_subjects
  )
}

resource "aws_iam_role" "gha_oidc_role" {
  name        = "${local.resource_prefix}-gha-terraform-role"
  description = "IAM role for GitHub Actions to run Terraform/Terragrunt"

  # Maximum session duration (1 hour for security)
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.all_allowed_subjects
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-gha-terraform-role"
  })
}

################################################################################
# IAM Policy for Terraform State Management (Least Privilege)
################################################################################

resource "aws_iam_role_policy" "gha_tfstate" {
  name   = "${local.resource_prefix}-terraform-state-access"
  role   = aws_iam_role.gha_oidc_role.id
  policy = data.aws_iam_policy_document.tfstate_policy.json
}

data "aws_iam_policy_document" "tfstate_policy" {
  # S3 State Bucket - List permissions
  statement {
    sid    = "S3StateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  # S3 State Bucket - Object permissions
  statement {
    sid    = "S3StateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  # DynamoDB Lock Table
  statement {
    sid    = "DynamoDBLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = [aws_dynamodb_table.tfstate_lock.arn]
  }

  # KMS Key for State Encryption
  statement {
    sid    = "KMSStateEncryption"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.tfstate.arn]
  }
}

################################################################################
# IAM Policy for Terraform Infrastructure Management
# Customize based on your infrastructure needs
################################################################################

resource "aws_iam_role_policy" "gha_infrastructure" {
  name   = "${local.resource_prefix}-terraform-infrastructure-access"
  role   = aws_iam_role.gha_oidc_role.id
  policy = data.aws_iam_policy_document.infrastructure_policy.json
}

data "aws_iam_policy_document" "infrastructure_policy" {
  # Read-only access for Terraform planning
  statement {
    sid    = "ReadOnlyAccess"
    effect = "Allow"
    actions = [
      # EC2 Read
      "ec2:Describe*",
      "ec2:Get*",

      # VPC Read
      "vpc:Describe*",

      # IAM Read (for planning)
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListRoles",
      "iam:ListPolicies",

      # Lambda Read
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListFunctions",
      "lambda:GetPolicy",

      # S3 Read (for other buckets)
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketTagging",
      "s3:GetBucketLogging",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:ListBucket",
      "s3:ListAllMyBuckets",

      # CloudWatch Read
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",

      # SNS Read
      "sns:GetTopicAttributes",
      "sns:ListTopics",

      # SQS Read
      "sqs:GetQueueAttributes",
      "sqs:ListQueues",

      # SSM Read
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DescribeParameters",

      # Secrets Manager Read
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",

      # API Gateway Read
      "apigateway:GET",

      # DynamoDB Read
      "dynamodb:DescribeTable",
      "dynamodb:ListTables",

      # Route53 Read
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",

      # ACM Read
      "acm:DescribeCertificate",
      "acm:ListCertificates",

      # CloudFront Read
      "cloudfront:GetDistribution",
      "cloudfront:ListDistributions",

      # ECR Read
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",

      # STS
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # Lambda Web App Deployment Permissions
  # Required for deploying Lambda container-based web applications
  #-----------------------------------------------------------------------------

  statement {
    sid    = "ECRAccess"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaAccess"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListFunctions",
      "lambda:GetPolicy",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:CreateFunctionUrlConfig",
      "lambda:UpdateFunctionUrlConfig",
      "lambda:DeleteFunctionUrlConfig",
      "lambda:GetFunctionUrlConfig",
      "lambda:InvokeFunction",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "APIGatewayAccess"
    effect = "Allow"
    actions = [
      "apigateway:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchAlarmsAccess"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion"
    ]
    resources = [
      "arn:aws:iam::*:role/${var.project_name}-*",
      "arn:aws:iam::*:policy/${var.project_name}-*"
    ]
  }

  # Write access - CUSTOMIZE BASED ON YOUR NEEDS
  # Start with read-only and add write permissions as needed
  # Example: Uncomment and modify for your use case

  # statement {
  #   sid    = "EC2WriteAccess"
  #   effect = "Allow"
  #   actions = [
  #     "ec2:CreateVpc",
  #     "ec2:DeleteVpc",
  #     "ec2:CreateSubnet",
  #     "ec2:DeleteSubnet",
  #     "ec2:CreateSecurityGroup",
  #     "ec2:DeleteSecurityGroup",
  #     "ec2:AuthorizeSecurityGroupIngress",
  #     "ec2:RevokeSecurityGroupIngress",
  #     "ec2:AuthorizeSecurityGroupEgress",
  #     "ec2:RevokeSecurityGroupEgress",
  #     "ec2:CreateTags",
  #     "ec2:DeleteTags"
  #   ]
  #   resources = ["*"]
  #   condition {
  #     test     = "StringEquals"
  #     variable = "aws:RequestedRegion"
  #     values   = [var.aws_region]
  #   }
  # }
}

################################################################################
# Optional: Attach Additional Managed Policies
################################################################################

resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each   = toset(var.additional_iam_policy_arns)
  role       = aws_iam_role.gha_oidc_role.name
  policy_arn = each.value
}

################################################################################
# Permissions Boundary (Optional but Recommended)
# Prevents privilege escalation
################################################################################

resource "aws_iam_policy" "gha_permissions_boundary" {
  name        = "${local.resource_prefix}-gha-permissions-boundary"
  description = "Permissions boundary for GitHub Actions role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowedServices"
        Effect = "Allow"
        Action = [
          "s3:*",
          "dynamodb:*",
          "lambda:*",
          "logs:*",
          "ec2:*",
          "iam:Get*",
          "iam:List*",
          "iam:PassRole",
          "ssm:*",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "sns:*",
          "sqs:*",
          "apigateway:*",
          "route53:*",
          "acm:*",
          "cloudfront:*",
          "cloudwatch:*",
          "sts:GetCallerIdentity",
          "sts:AssumeRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMWrite"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:CreateGroup",
          "iam:DeleteGroup",
          "iam:UpdateLoginProfile",
          "iam:CreateLoginProfile",
          "iam:DeleteLoginProfile"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyOrganizationsActions"
        Effect = "Deny"
        Action = [
          "organizations:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-gha-permissions-boundary"
  })
}

# Uncomment to apply the permissions boundary
# resource "aws_iam_role" "gha_oidc_role" {
#   ...
#   permissions_boundary = aws_iam_policy.gha_permissions_boundary.arn
# }
