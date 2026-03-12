################################################################################
# Resource Group for Network Resources
# Allows viewing all network resources in AWS Console
################################################################################

locals {
  rg_name = "${local.resource_prefix}-rg-network"
}

resource "aws_resourcegroups_group" "rg" {
  for_each = toset(var.aws_allowed_regions)

  name        = "${local.rg_name}-${each.key}"
  description = "Resource group containing network Terraform infrastructure"

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
          Values = ["network"]
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    Name = local.rg_name
  })
}
