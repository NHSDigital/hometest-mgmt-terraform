################################################################################
# Resource Group for rds-postgres Resources
# Allows viewing all rds-postgres resources in AWS Console
################################################################################

locals {
  rg_name = "${local.resource_prefix}-rg-rds-postgres"
}

resource "aws_resourcegroups_group" "rg" {
  for_each = toset(var.aws_allowed_regions)

  name        = "${local.rg_name}-${each.key}"
  description = "Resource group containing rds-postgres Terraform infrastructure"

  region = each.key

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        },
        {
          Key    = "ManagedBy"
          Values = ["terraform"]
        },
        {
          Key    = "Component"
          Values = ["rds-postgres"]
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    Name = local.rg_name
  })
}
