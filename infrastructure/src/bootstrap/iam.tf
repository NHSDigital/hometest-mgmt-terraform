# module "gha_oidc_role" {
#   # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws
#   source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"  # Or philips-labs one
#   version = "~> 6.3"

#   # create_provider = true

#   # github_repos = [var.github_repo]  # e.g., "yourusername/your-repo"

#   # iam_role_name = "${var.namespace}-${var.stage}-gha-role"

#   # iam_role_policies = {
#   #   tfstate = data.aws_iam_policy_document.gha_policy.json  # Reuse policy
#   # }

#   # source    = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"

#   url = "https://token.actions.githubusercontent.com"

#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }


# OIDC Provider (account-level, create once)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",  # GitHub OIDC thumbprint (stable)
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # Additional thumbprint for GitHub Actions (June 2023)
  ]

  tags = {
    Name = "github-oidc-provider"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "gha_oidc_role" {
  name = "${var.account_name}-gha-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repo}:*"  # e.g., "repo:yourusername/your-repo:*" for all branches
            ]
          }
        }
      }
    ]
  })

  tags = {
    # Name = "${var.namespace}-${var.stage}-gha-role"
  }
}

# Attach tfstate policy
resource "aws_iam_role_policy" "gha_tfstate" {
  name   = "tfstate"
  role   = aws_iam_role.gha_oidc_role.id
  policy = data.aws_iam_policy_document.gha_policy.json  # Your existing S3/DynamoDB policy
}

# Outputs for GitHub secrets
output "gha_oidc_role_arn" {
  value = aws_iam_role.gha_oidc_role.arn
  description = "ARN to store as AWS_ROLE_ARN in GitHub secrets"
}

variable "account_name" {}
variable "github_repo" {}

data "aws_iam_policy_document" "gha_policy" {
  statement {
    sid    = "S3State"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["*"]
  #   resources = [
  #     aws_s3_bucket.tfstate.arn,
  #     "${aws_s3_bucket.tfstate.arn}/*"
  #   ]
  }

  # statement {
  #   sid    = "DynamoLock"
  #   effect = "Allow"
  #   actions = [
  #     "dynamodb:GetItem",
  #     "dynamodb:PutItem",
  #     "dynamodb:DeleteItem"
  #   ]
  #   resources = [aws_dynamodb_table.tfstate_lock.arn]
  # }

  # Add more for your resources, e.g., EC2/VPC
  # statement {
  #   sid    = "EC2Full"
  #   effect = "Allow"
  #   actions = ["ec2:*"]
  #   resources = "*"
  # }
}
