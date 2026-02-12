################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.vpc_id
}

################################################################################
# Aurora Cluster Outputs
################################################################################

output "cluster_id" {
  description = "The Amazon RDS Aurora cluster ID"
  value       = module.aurora_db.cluster_id
}

output "cluster_arn" {
  description = "The Amazon RDS Aurora cluster ARN"
  value       = module.aurora_db.cluster_arn
}

output "cluster_endpoint" {
  description = "The writer endpoint of the Aurora cluster"
  value       = module.aurora_db.cluster_endpoint
}

output "cluster_database_name" {
  description = "The database name in the Aurora cluster"
  value       = module.aurora_db.cluster_database_name
}

output "cluster_master_username" {
  description = "The master username for the Aurora cluster"
  value       = module.aurora_db.cluster_master_username
  sensitive   = true
}

output "cluster_port" {
  description = "The port the Aurora cluster listens on"
  value       = module.aurora_db.cluster_port
}

output "cluster_hosted_zone_id" {
  description = "The canonical hosted zone ID of the Aurora cluster (for Route 53 Alias)"
  value       = module.aurora_db.cluster_hosted_zone_id
}

output "connection_string" {
  description = "Aurora PostgreSQL connection string (without password)"
  value       = module.aurora_db.connection_string
  sensitive   = true
}
