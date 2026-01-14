################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"
  # resource_prefix = "${var.project_name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  common_tags = merge(var.tags, {
    Component = "bootstrap"
  })
}

# Tags applied to all resources
### Provider tags
# Project
# hometest

# Environment
# mgmt

# ManagedBy
# terraform

# Repository
# NHSDigital/hometest-mgmt-terraform

### Tags from all.hcl
# Owner
# platform-team

# CostCenter
# infrastructure

# Application
# hometest

### common_tags from bootstrap main.tf
# Component
# bootstrap

### Added resource tags
# Name
# github-oidc-provider
