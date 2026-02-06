################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.vpc_id
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group used"
  value       = var.db_subnet_group_name
}

################################################################################
# RDS Instance Outputs
################################################################################

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = module.rds_postgres.db_instance_id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds_postgres.db_instance_arn
}

output "db_instance_endpoint" {
  description = "The connection endpoint in address:port format"
  value       = module.rds_postgres.db_instance_endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = module.rds_postgres.db_instance_address
}

output "db_instance_port" {
  description = "The database port"
  value       = module.rds_postgres.db_instance_port
}

output "db_instance_name" {
  description = "The database name"
  value       = module.rds_postgres.db_instance_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = module.rds_postgres.db_instance_username
  sensitive   = true
}

output "db_instance_master_user_secret_arn" {
  description = "The ARN of the master user secret in Secrets Manager"
  value       = module.rds_postgres.db_instance_master_user_secret_arn
  sensitive   = true
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = module.rds_postgres.security_group_id
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = module.rds_postgres.connection_string
  sensitive   = true
}
