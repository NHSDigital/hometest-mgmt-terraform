################################################################################
# Route 53 Hosted Zone
################################################################################

resource "aws_route53_zone" "main" {
  name    = var.route53_zone_name
  comment = "Hosted zone for ${local.resource_prefix}"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-zone"
  })
}

################################################################################
# Route 53 Private Hosted Zone (Optional - for internal DNS)
################################################################################

resource "aws_route53_zone" "private" {
  count = var.create_private_hosted_zone ? 1 : 0

  name    = var.private_zone_name != "" ? var.private_zone_name : var.route53_zone_name
  comment = "Private hosted zone for ${local.resource_prefix}"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-private-zone"
  })

  lifecycle {
    ignore_changes = [vpc]
  }
}

################################################################################
# Route 53 Health Check (Optional)
################################################################################

resource "aws_route53_health_check" "main" {
  count = var.create_health_check ? 1 : 0

  fqdn              = var.health_check_fqdn != "" ? var.health_check_fqdn : var.route53_zone_name
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-health-check"
  })
}

################################################################################
# Route 53 DNSSEC (Optional - Enhanced Security)
################################################################################

resource "aws_route53_key_signing_key" "main" {
  count = var.enable_dnssec ? 1 : 0

  hosted_zone_id             = aws_route53_zone.main.id
  key_management_service_arn = aws_kms_key.dnssec[0].arn
  name                       = "${local.resource_prefix}-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  count = var.enable_dnssec ? 1 : 0

  hosted_zone_id = aws_route53_zone.main.id

  depends_on = [aws_route53_key_signing_key.main]
}

resource "aws_kms_key" "dnssec" {
  count = var.enable_dnssec ? 1 : 0

  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Route 53 DNSSEC Service"
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:route53:::hostedzone/*"
          }
        }
      },
      {
        Sid    = "Allow Route 53 DNSSEC to CreateGrant"
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Action   = "kms:CreateGrant"
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-dnssec-kms"
  })
}

resource "aws_kms_alias" "dnssec" {
  count = var.enable_dnssec ? 1 : 0

  name          = "alias/${local.resource_prefix}-dnssec"
  target_key_id = aws_kms_key.dnssec[0].key_id
}
