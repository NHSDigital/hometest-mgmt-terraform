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
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = ["${var.aws_account_id}"]

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.github_repo
    }
  }
}
