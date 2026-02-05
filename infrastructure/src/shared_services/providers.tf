################################################################################
# Shared Services Infrastructure
# Contains resources shared across all environments:
# - WAF Web ACL (shared across API Gateways and CloudFront)
# - ACM Certificates (regional and global)
# - KMS Keys for encryption
# - Deployment Artifacts S3 Bucket
# - Developer IAM Role
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
