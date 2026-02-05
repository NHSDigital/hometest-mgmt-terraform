################################################################################
# HomeTest Service Application Infrastructure
# Deploys environment-specific resources:
# - 2 API Lambdas with API Gateway
# - CloudFront SPA
# - Route53 DNS records
#
# Dependencies (from Terragrunt):
# - network: VPC, subnets, security groups, Route53 zone
# - shared_services: KMS, WAF, ACM certificates, deployment bucket
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
