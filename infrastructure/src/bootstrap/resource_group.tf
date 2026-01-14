################################################################################
# Resource Group for Bootstrap Resources
# Allows viewing all bootstrap resources in AWS Console
################################################################################

locals {
  rg_name = "${local.resource_prefix}-rg-bootstrap"
}

resource "aws_resourcegroups_group" "bootstrap" {
  name        = local.rg_name
  description = "Resource group containing all Terraform bootstrap infrastructure"

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
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    Name = local.rg_name
  })
}
