################################################################################
# Lambda Execution IAM Role
################################################################################

module "lambda_iam" {
  source = "../../modules/lambda-iam"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = local.account_id
  aws_region     = local.region

  enable_xray       = true
  enable_vpc_access = var.enable_vpc_access
  vpc_id            = var.vpc_id

  secrets_arns        = var.lambda_secrets_arns
  ssm_parameter_arns  = var.lambda_ssm_parameter_arns
  kms_key_arns        = var.kms_key_arn != null ? [var.kms_key_arn] : []
  s3_bucket_arns      = concat([var.deployment_bucket_arn], var.lambda_s3_bucket_arns)
  dynamodb_table_arns = var.lambda_dynamodb_table_arns
  sqs_queue_arns      = var.lambda_sqs_queue_arns

  tags = var.tags
}
