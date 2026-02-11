################################################################################
# Resource Group for shared-services Resources
# Allows viewing all shared-services resources in AWS Console
################################################################################

locals {
  rg_name = "${local.resource_prefix}-rg-shared-services"
}

resource "aws_resourcegroups_group" "rg" {
  for_each = toset(var.aws_allowed_regions)

  name        = "${local.rg_name}-${each.key}"
  description = "Resource group containing shared-services Terraform infrastructure"

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
          Values = ["shared-services"]
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    Name = local.rg_name
  })
}
