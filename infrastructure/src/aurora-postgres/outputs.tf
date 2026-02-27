################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.vpc_id
}

################################################################################
# Aurora Cluster Outputs
################################################################################

output "cluster_id" {
  description = "The Amazon RDS Aurora cluster ID"
  value       = module.aurora_postgres.cluster_id
}

output "cluster_arn" {
  description = "The Amazon RDS Aurora cluster ARN"
  value       = module.aurora_postgres.cluster_arn
}

output "cluster_endpoint" {
  description = "The writer endpoint of the Aurora cluster"
  value       = module.aurora_postgres.cluster_endpoint
}

output "cluster_database_name" {
  description = "The database name in the Aurora cluster"
  value       = module.aurora_postgres.cluster_database_name
}

output "cluster_master_username" {
  description = "The master username for the Aurora cluster"
  value       = module.aurora_postgres.cluster_master_username
  sensitive   = true
}

output "cluster_port" {
  description = "The port the Aurora cluster listens on"
  value       = module.aurora_postgres.cluster_port
}

output "cluster_hosted_zone_id" {
  description = "The canonical hosted zone ID of the Aurora cluster (for Route 53 Alias)"
  value       = module.aurora_postgres.cluster_hosted_zone_id
}

output "connection_string" {
  description = "Aurora PostgreSQL connection string (without password)"
  value       = module.aurora_postgres.connection_string
  sensitive   = true
}

output "cluster_resource_id" {
  description = "The RDS cluster resource ID, used for IAM authentication ARNs"
  value       = module.aurora_postgres.cluster_resource_id
}

output "cluster_master_user_secret_arn" {
  description = "The ARN of the Secrets Manager secret for the Aurora master user password"
  value       = module.aurora_postgres.cluster_master_user_secret_arn
  sensitive   = true
}

output "cluster_master_user_secret_name" {
  description = "The Secrets Manager secret name for the Aurora master user password"
  value       = module.aurora_postgres.cluster_master_user_secret_name
  sensitive   = true
}
