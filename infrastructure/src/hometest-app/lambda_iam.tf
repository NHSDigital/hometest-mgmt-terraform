################################################################################
# Lambda Execution IAM Role
################################################################################

locals {
  # Collect all secrets ARNs from lambda definitions
  lambda_secrets_from_map = compact([
    for k, v in local.all_lambdas : try(v.secrets_arn, null)
  ])

  # Combine with variable-provided secrets ARNs
  all_secrets_arns = distinct(concat(var.lambda_secrets_arns, local.lambda_secrets_from_map))

  # SQS queue ARNs (add the event queue if any lambda has sqs_trigger, and order-results queue if enabled)
  sqs_queue_arns = distinct(concat(
    var.lambda_sqs_queue_arns,
    length(local.sqs_lambdas) > 0 ? [aws_sqs_queue.main[0].arn] : [],
    var.enable_sqs_access ? [aws_sqs_queue.order_results[0].arn] : []
  ))
}

module "lambda_iam" {
  source = "../../modules/lambda-iam"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  enable_xray       = true
  enable_vpc_access = var.enable_vpc_access
  vpc_id            = var.vpc_id

  secrets_arns       = local.all_secrets_arns
  ssm_parameter_arns = var.lambda_ssm_parameter_arns
  kms_key_arns = concat(
    var.kms_key_arn != null ? [var.kms_key_arn] : [],
    var.lambda_additional_kms_key_arns
  )
  # s3_bucket_arns      = concat([var.deployment_bucket_arn], var.lambda_s3_bucket_arns)
  s3_bucket_arns      = concat(var.lambda_s3_bucket_arns)
  dynamodb_table_arns = var.lambda_dynamodb_table_arns
  sqs_queue_arns      = local.sqs_queue_arns
  enable_sqs_access   = var.enable_sqs_access || length(local.sqs_lambdas) > 0 || length(var.lambda_sqs_queue_arns) > 0

  aurora_cluster_resource_ids = var.lambda_aurora_cluster_resource_ids

  tags = local.common_tags

  depends_on = [aws_sqs_queue.main, aws_sqs_queue.order_results]
}
