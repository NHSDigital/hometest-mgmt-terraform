
# Expose the ARN of the master user secret in Secrets Manager (if managed)
output "db_instance_master_user_secret_arn" {
  description = "ARN of master password secret in Secrets Manager"
  value       = module.aurora.cluster_master_user_secret_arn
  sensitive   = true
}
################################################################################
# RDS Instance Outputs
################################################################################


output "cluster_id" {
  description = "The Amazon RDS Aurora cluster ID"
  value       = module.aurora.cluster_id
}

output "cluster_arn" {
  description = "The Amazon RDS Aurora cluster ARN"
  value       = module.aurora.cluster_arn
}

output "cluster_endpoint" {
  description = "The writer endpoint of the Aurora cluster"
  value       = module.aurora.cluster_endpoint
}

output "cluster_database_name" {
  description = "The database name in the Aurora cluster"
  value       = module.aurora.cluster_database_name
}

output "cluster_master_username" {
  description = "The master username for the Aurora cluster"
  value       = module.aurora.cluster_master_username
  sensitive   = true
}

output "cluster_port" {
  description = "The port the Aurora cluster listens on"
  value       = module.aurora.cluster_port
}

output "cluster_hosted_zone_id" {
  description = "The canonical hosted zone ID of the Aurora cluster (for Route 53 Alias)"
  value       = module.aurora.cluster_hosted_zone_id
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
  value       = module.aurora.db_parameter_group_id
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = module.aurora.db_parameter_group_arn
}

################################################################################
# Connection String
################################################################################

output "connection_string" {
  description = "Aurora PostgreSQL connection string (without password)"
  value       = "postgresql://${module.aurora.cluster_master_username}@${module.aurora.cluster_endpoint}:${module.aurora.cluster_port}/${module.aurora.cluster_database_name}"
  sensitive   = true
}
