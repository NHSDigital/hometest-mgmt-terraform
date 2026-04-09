resource "aws_iam_role" "lambda_goose_migrator" {
  name               = "${local.resource_prefix}-goose-migrator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-goose-migrator-role"
  })
}

resource "aws_iam_policy" "lambda_goose_migrator_policy" {
  name        = "${local.resource_prefix}-goose-migrator-policy"
  description = "Allow Lambda to connect to RDS and fetch secrets."
  policy      = data.aws_iam_policy_document.lambda_goose_migrator_policy.json

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-goose-migrator-policy"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_goose_migrator_attach" {
  role       = aws_iam_role.lambda_goose_migrator.name
  policy_arn = aws_iam_policy.lambda_goose_migrator_policy.arn
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_goose_migrator_policy" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # Restrict Secrets Manager access to only the specific secrets this Lambda needs.
  # All referenced secrets MUST be encrypted with the CMK specified in var.kms_key_arn.
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = compact([
      try(data.aws_rds_cluster.db.master_user_secret[0].secret_arn, ""),
      var.db_schema != "public" ? aws_secretsmanager_secret.app_user[0].arn : ""
    ])
  }

  # Only allow decryption using the customer-managed KMS key (pii-data key).
  # This ensures the Lambda cannot decrypt secrets encrypted with the AWS-managed
  # aws/secretsmanager key — only CMK-encrypted secrets are accessible.
  statement {
    sid    = "KMSDecryptCMKOnly"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.kms_key_arn]
  }

  statement {
    sid       = "RDSIAMConnect"
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = ["*"]
  }

  statement {
    sid    = "VPCNetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }
}
