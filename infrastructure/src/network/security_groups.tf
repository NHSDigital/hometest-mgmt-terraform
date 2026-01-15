################################################################################
# Security Groups for Lambda Functions
################################################################################

resource "aws_security_group" "lambda" {
  name        = "${local.resource_prefix}-lambda-sg"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.main.id

  # Lambda functions typically only need outbound access
  egress {
    description = "HTTPS outbound for AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "DNS resolution TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security Group for Lambda to RDS access
################################################################################

resource "aws_security_group" "lambda_rds" {
  count = var.create_lambda_rds_sg ? 1 : 0

  name        = "${local.resource_prefix}-lambda-rds-sg"
  description = "Security group for Lambda functions accessing RDS"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = local.data_subnets
  }

  egress {
    description = "MySQL to RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = local.data_subnets
  }

  egress {
    description = "HTTPS for AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-lambda-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security Group for RDS/Database
################################################################################

resource "aws_security_group" "rds" {
  count = var.create_rds_sg ? 1 : 0

  name        = "${local.resource_prefix}-rds-sg"
  description = "Security group for RDS databases"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = compact([aws_security_group.lambda.id, try(aws_security_group.lambda_rds[0].id, "")])
  }

  ingress {
    description     = "MySQL from Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = compact([aws_security_group.lambda.id, try(aws_security_group.lambda_rds[0].id, "")])
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security Group for ElastiCache/Redis
################################################################################

resource "aws_security_group" "elasticache" {
  count = var.create_elasticache_sg ? 1 : 0

  name        = "${local.resource_prefix}-elasticache-sg"
  description = "Security group for ElastiCache"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from Lambda"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-elasticache-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
