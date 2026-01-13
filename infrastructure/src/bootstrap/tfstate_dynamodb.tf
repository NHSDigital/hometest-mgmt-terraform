################################################################################
# DynamoDB Table for State Locking
################################################################################

locals {
  tfstate_dynamodb_name = "${local.resource_prefix}-dynamodb-tfstate-lock"
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${local.resource_prefix}-dynamodb-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST" # Cost-effective for variable workloads
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Point-in-time recovery for disaster recovery
  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  # Server-side encryption with KMS
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  # Deletion protection
  deletion_protection_enabled = true

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate-lock"
  })
}
