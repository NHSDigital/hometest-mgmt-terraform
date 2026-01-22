################################################################################
# API Gateway Security Group (for Private API Gateway with VPC Link)
################################################################################

resource "aws_security_group" "api_gateway" {
  count = var.create_api_gateway_sg ? 1 : 0

  name        = "${local.resource_prefix}-api-gateway-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from allowed sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.api_gateway_allowed_cidrs
  }

  egress {
    description     = "Allow traffic to Lambda security group"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-api-gateway-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# VPC Link for Private API Gateway Integration
################################################################################

resource "aws_apigatewayv2_vpc_link" "main" {
  count = var.create_vpc_link ? 1 : 0

  name               = "${local.resource_prefix}-vpc-link"
  security_group_ids = [aws_security_group.api_gateway[0].id]
  subnet_ids         = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-vpc-link"
  })
}

################################################################################
# API Gateway Resource Policy (Optional - Restrict Access)
################################################################################

# Example policy for restricting API Gateway access to specific IPs/VPCs
# This can be attached to API Gateway using aws_api_gateway_rest_api_policy

locals {
  api_gateway_resource_policy = var.create_api_gateway_resource_policy ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Allow from specific IP addresses
      length(var.api_gateway_allowed_ips) > 0 ? [{
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.api_gateway_allowed_ips
          }
        }
      }] : [],
      # Allow from VPC endpoints
      var.api_gateway_allow_from_vpc ? [{
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpc" = aws_vpc.main.id
          }
        }
      }] : [],
      # Deny all other access (implicit if only allowing specific sources)
      [{
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*"
        Condition = {
          StringNotEquals = {
            "aws:SourceVpc" = aws_vpc.main.id
          }
          NotIpAddress = {
            "aws:SourceIp" = var.api_gateway_allowed_ips
          }
        }
      }]
    )
  }) : null
}
