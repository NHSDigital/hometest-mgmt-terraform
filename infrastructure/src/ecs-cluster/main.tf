################################################################################
# ECS Cluster (Fargate) - Core Infrastructure
# Shared ECS cluster used by all environments for container workloads.
# Uses terraform-aws-modules/ecs/aws for the cluster and capacity providers.
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "ecs-cluster"
  })
}

################################################################################
# ECS Cluster via official AWS module
# https://github.com/terraform-aws-modules/terraform-aws-ecs/releases
################################################################################

module "ecs_cluster" {
  #checkov:skip=CKV_TF_1:Using a commit hash for module from the Terraform registry is not applicable
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.12.0"

  cluster_name = "${local.resource_prefix}-ecs"

  # Container Insights for observability
  cluster_settings = {
    name  = "containerInsights"
    value = "enhanced"
  }

  # ECS Exec audit logging (encrypted)
  cluster_configuration = {
    execute_command_configuration = {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"
      log_configuration = {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  # Fargate capacity providers — FARGATE_SPOT as default for cost savings (dev-only workloads)
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 0
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
  }

  tags = local.common_tags
}

################################################################################
# CloudWatch Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/ecs/${local.resource_prefix}/exec-audit"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

################################################################################
# Service Discovery Namespace (Private DNS)
################################################################################

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "ecs.${local.resource_prefix}.local"
  description = "Service discovery namespace for ECS services"
  vpc         = var.vpc_id

  tags = local.common_tags
}
