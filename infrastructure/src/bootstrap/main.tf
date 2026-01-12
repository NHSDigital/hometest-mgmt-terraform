# resource "aws_s3_bucket" "tfstate" {
#   bucket = "${var.namespace}-${var.stage}-${var.bucket_suffix}"

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# resource "aws_s3_bucket_versioning" "tfstate" {
#   bucket = aws_s3_bucket.tfstate.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
#   bucket = aws_s3_bucket.tfstate.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "tfstate" {
#   bucket = aws_s3_bucket.tfstate.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_dynamodb_table" "tfstate_lock" {
#   name         = "${var.namespace}-${var.stage}-tfstate-lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# locals {
#   backend_config = templatefile("${path.module}/backend.tpl", {
#     bucket         = aws_s3_bucket.tfstate.bucket
#     key            = "gha/terraform.tfstate"
#     region         = var.aws_region
#     dynamodb_table = aws_dynamodb_table.tfstate_lock.name
#   })
# }

# resource "local_file" "backend_hcl" {
#   content  = local.backend_config
#   filename = "${path.module}/backend.hcl"
# }
