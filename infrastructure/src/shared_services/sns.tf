################################################################################
# SNS Topics
# Shared SNS topics for the hometest application
################################################################################

#------------------------------------------------------------------------------
# Alerts Topic
# Used for infrastructure and SQS alarm notifications
#------------------------------------------------------------------------------

module "sns_alerts" {
  source = "../../modules/sns"

  project_name      = var.project_name
  environment       = var.environment
  topic_name_suffix = "alerts"

  # Encryption
  kms_master_key_id = aws_kms_key.main.id

  # Tags
  tags = local.common_tags
}
