################################################################################
# VPC Endpoints - Cost Optimization & Security for Lambda
################################################################################

# Gateway Endpoints (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.data.id]
  )

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-s3-endpoint"
  })
}

# DynamoDB not used in this deployment - only RDS PostgreSQL, Lambda, API Gateway, WAF, SQS, S3

# Security Group for Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.resource_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # trivy:ignore:AVD-AWS-0104
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-vpc-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Interface Endpoints for Lambda and common AWS services
resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = var.enable_interface_endpoints ? toset(var.interface_endpoints) : toset([])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-${each.value}-endpoint"
  })
}
