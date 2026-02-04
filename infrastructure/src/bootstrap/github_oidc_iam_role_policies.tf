################################################################################
# IAM Policy for Terraform State Management (Least Privilege)
################################################################################

resource "aws_iam_role_policy" "gha_tfstate" {
  name   = "${local.gha_iam_role_name}-policy-tfstate-access"
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
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags"
    ]
    resources = [aws_kms_key.tfstate.arn]
  }
}

################################################################################
# IAM Policy for Terraform Infrastructure Management
# Customize based on your infrastructure needs
################################################################################

resource "aws_iam_role_policy" "gha_infrastructure" {
  name   = "${local.gha_iam_role_name}-policy-infrastructure-access"
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
      "s3:GetBucketWebsite",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
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
      "sts:GetCallerIdentity",

      # Resource Groups
      "resource-groups:GetGroup",
      "resource-groups:GetGroupConfiguration",
      "resource-groups:GetGroupQuery",
      "resource-groups:ListGroupResources",
      "resource-groups:GetTags"
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

  #-----------------------------------------------------------------------------
  # VPC and Networking Permissions
  # Required for network infrastructure deployment
  #-----------------------------------------------------------------------------

  statement {
    sid    = "VPCNetworkingAccess"
    effect = "Allow"
    actions = [
      # VPC
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:AssociateVpcCidrBlock",
      "ec2:DisassociateVpcCidrBlock",

      # Subnets
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",

      # Internet Gateway
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",

      # NAT Gateway
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",

      # Route Tables
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:ReplaceRouteTableAssociation",

      # Security Groups
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",

      # Network ACLs
      "ec2:CreateNetworkAcl",
      "ec2:DeleteNetworkAcl",
      "ec2:CreateNetworkAclEntry",
      "ec2:DeleteNetworkAclEntry",
      "ec2:ReplaceNetworkAclEntry",
      "ec2:ReplaceNetworkAclAssociation",

      # VPC Endpoints
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
      "ec2:ModifyVpcEndpoint",

      # VPC Flow Logs
      "ec2:CreateFlowLogs",
      "ec2:DeleteFlowLogs",

      # Tags
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # AWS Network Firewall Permissions
  # Required for egress filtering deployment
  #-----------------------------------------------------------------------------

  statement {
    sid    = "NetworkFirewallAccess"
    effect = "Allow"
    actions = [
      "network-firewall:CreateFirewall",
      "network-firewall:DeleteFirewall",
      "network-firewall:UpdateFirewallDescription",
      "network-firewall:UpdateFirewallDeleteProtection",
      "network-firewall:UpdateFirewallPolicy",
      "network-firewall:UpdateFirewallPolicyChangeProtection",
      "network-firewall:UpdateSubnetChangeProtection",
      "network-firewall:AssociateFirewallPolicy",
      "network-firewall:DisassociateSubnets",
      "network-firewall:AssociateSubnets",
      "network-firewall:DescribeFirewall",
      "network-firewall:DescribeFirewallPolicy",
      "network-firewall:DescribeRuleGroup",
      "network-firewall:DescribeLoggingConfiguration",
      "network-firewall:ListFirewalls",
      "network-firewall:ListFirewallPolicies",
      "network-firewall:ListRuleGroups",
      "network-firewall:CreateFirewallPolicy",
      "network-firewall:DeleteFirewallPolicy",
      "network-firewall:UpdateFirewallPolicy",
      "network-firewall:CreateRuleGroup",
      "network-firewall:DeleteRuleGroup",
      "network-firewall:UpdateRuleGroup",
      "network-firewall:UpdateLoggingConfiguration",
      "network-firewall:TagResource",
      "network-firewall:UntagResource",
      "network-firewall:ListTagsForResource"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # Route53 Write Permissions
  # Required for DNS management
  #-----------------------------------------------------------------------------

  statement {
    sid    = "Route53WriteAccess"
    effect = "Allow"
    actions = [
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:UpdateHostedZoneComment",
      "route53:ChangeResourceRecordSets",
      "route53:CreateHealthCheck",
      "route53:DeleteHealthCheck",
      "route53:UpdateHealthCheck",
      "route53:GetHealthCheck",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:GetChange",
      "route53:ChangeTagsForResource",
      "route53:ListTagsForResource",
      "route53:AssociateVPCWithHostedZone",
      "route53:DisassociateVPCFromHostedZone",
      "route53:CreateQueryLoggingConfig",
      "route53:DeleteQueryLoggingConfig",
      "route53:GetQueryLoggingConfig",
      "route53:ListQueryLoggingConfigs"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # KMS Key Management Permissions
  # Required for encryption key management (VPC Flow Logs, etc.)
  #-----------------------------------------------------------------------------

  statement {
    sid    = "KMSKeyManagement"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ListAliases",
      "kms:ListKeys"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # S3 Bucket Management Permissions
  # Required for S3 bucket deployment and management
  #-----------------------------------------------------------------------------

  statement {
    sid    = "S3BucketManagement"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketAcl",
      "s3:PutBucketCORS",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketTagging",
      "s3:PutBucketLogging",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketWebsite",
      "s3:DeleteBucketWebsite",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
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
      "s3:GetBucketWebsite",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:GetReplicationConfiguration",
      "s3:PutReplicationConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:PutBucketOwnershipControls",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # DynamoDB Permissions
  # Required for state locking and application tables
  #-----------------------------------------------------------------------------

  statement {
    sid    = "DynamoDBManagement"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:UpdateTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # Resource Groups Permissions
  # Required for resource group management
  #-----------------------------------------------------------------------------

  statement {
    sid    = "ResourceGroupsManagement"
    effect = "Allow"
    actions = [
      "resource-groups:CreateGroup",
      "resource-groups:DeleteGroup",
      "resource-groups:UpdateGroup",
      "resource-groups:UpdateGroupQuery",
      "resource-groups:GetGroup",
      "resource-groups:GetGroupConfiguration",
      "resource-groups:GetGroupQuery",
      "resource-groups:ListGroupResources",
      "resource-groups:GetTags",
      "resource-groups:Tag",
      "resource-groups:Untag",
      "resource-groups:PutGroupConfiguration"
    ]
    resources = ["*"]
  }

  #-----------------------------------------------------------------------------
  # IAM Service-Linked Roles
  # Required for Network Firewall and VPC Flow Logs
  #-----------------------------------------------------------------------------

  statement {
    sid    = "IAMServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:DeleteServiceLinkedRole",
      "iam:GetServiceLinkedRoleDeletionStatus"
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/network-firewall.amazonaws.com/*",
      "arn:aws:iam::*:role/aws-service-role/logs.amazonaws.com/*"
    ]
  }
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
  name        = "${local.gha_iam_role_name}-policy-gha-permissions-boundary"
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
    Name = "${local.gha_iam_role_name}-policy-gha-permissions-boundary"
  })
}

# Uncomment to apply the permissions boundary
# resource "aws_iam_role" "gha_oidc_role" {
#   ...
#   permissions_boundary = aws_iam_policy.gha_permissions_boundary.arn
# }
