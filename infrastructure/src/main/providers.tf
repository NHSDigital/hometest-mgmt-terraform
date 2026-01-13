################################################################################
# Terraform and Provider Configuration
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    })
  }
}

# Docker provider for building images (only needed if building locally)
# provider "docker" {
#   registry_auth {
#     address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
#     username = data.aws_ecr_authorization_token.token.user_name
#     password = data.aws_ecr_authorization_token.token.password
#   }
# }
