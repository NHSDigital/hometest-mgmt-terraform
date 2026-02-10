################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "shared-services"
  })
}
