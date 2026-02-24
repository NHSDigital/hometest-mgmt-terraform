
################################################################################
# Aurora Outputs
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

output "cluster_resource_id" {
  description = "The RDS cluster resource ID, used to build IAM auth ARNs (arn:aws:rds-db:region:account:dbuser:resource-id/db_user)"
  value       = module.aurora_postgres.cluster_resource_id
}

output "cluster_master_user_secret_arn" {
  description = "The ARN of the Secrets Manager secret holding the Aurora master user password"
  value       = module.aurora_postgres.cluster_master_user_secret[0].secret_arn
  sensitive   = true
}

output "cluster_master_user_secret_name" {
  description = "The Secrets Manager secret name for the Aurora master user password (derived from ARN)"
  value       = element(split(":", module.aurora_postgres.cluster_master_user_secret[0].secret_arn), 6)
  sensitive   = true
}

################################################################################
# Security Group Outputs
################################################################################

output "security_group_id" {
  description = "The ID of the security group"
  value       = module.security_group.security_group_id
}

output "security_group_arn" {
  description = "The ARN of the security group"
  value       = module.security_group.security_group_arn
}

output "security_group_name" {
  description = "The name of the security group"
  value       = module.security_group.security_group_name
}

################################################################################
# Parameter Group Outputs
################################################################################

output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = module.aurora_postgres.db_parameter_group_id
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = module.aurora_postgres.db_parameter_group_arn
}

################################################################################
# Connection String
################################################################################

output "connection_string" {
  description = "Aurora PostgreSQL connection string (without password)"
  value       = "postgresql://${module.aurora_postgres.cluster_master_username}@${module.aurora_postgres.cluster_endpoint}:${module.aurora_postgres.cluster_port}/${module.aurora_postgres.cluster_database_name}"
  sensitive   = true
}
