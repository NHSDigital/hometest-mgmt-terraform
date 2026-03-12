################################################################################
# Security Group
################################################################################

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.identifier}-sg"
  description = "Security group for RDS PostgreSQL instance ${var.identifier}"
  vpc_id      = var.vpc_id

  # Ingress rules
  ingress_with_cidr_blocks = var.allowed_cidr_blocks != [] ? [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from CIDR blocks"
      cidr_blocks = join(",", var.allowed_cidr_blocks)
    }
  ] : []

  ingress_with_source_security_group_id = [
    for sg_id in var.allowed_security_group_ids : {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "PostgreSQL access from security group"
      source_security_group_id = sg_id
    }
  ]

  # Egress rules - RDS doesn't need outbound access (responses use established connections)
  # Following AWS best practice: deny all egress for database security groups
  egress_rules = []

  tags = local.security_group_tags
}
