################################################################################
# Resource Group for SQS Resources
# Allows viewing all SQS resources in AWS Console
################################################################################

locals {
  rg_name = "${local.queue_name}-rg"
}

resource "aws_resourcegroups_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name        = local.rg_name
  description = "Resource group for ${local.queue_name} SQS queue and related resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Name"
          Values = [local.queue_name, local.dlq_name]
        },
        {
          Key    = "Module"
          Values = ["sqs"]
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
