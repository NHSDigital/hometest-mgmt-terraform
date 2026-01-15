################################################################################
# Terraform and Provider Configuration
################################################################################

terraform {
  required_version = ">= 1.14.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  # NOTE: After initial bootstrap, uncomment and configure backend
  # backend "s3" {
  #   bucket         = "your-bucket-name-tfstate"
  #   key            = "bootstrap/terraform.tfstate"
  #   region         = "eu-west-2"
  #   dynamodb_table = "your-table-name-tfstate-lock"
  #   encrypt        = true
  # }

  # https://wikijs.cloudnative.quest/en/aws/common-aws-services-and-acronyms
  # backend_config = {
  #   "bucket" = "hometest-mgmt-tfstate-781863586270"
  #   "dynamodb_table" = "hometest-mgmt-tfstate-lock"
  #   "encrypt" = true
  #   "kms_key_id" = "arn:aws:kms:eu-west-2:781863586270:key/e53f5420-a3b8-43d8-b8ab-87b65997fff7"
  #   "region" = "eu-west-2"
  # }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}
