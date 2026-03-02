output "app_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing app_user credentials"
  value       = var.db_schema != "public" ? aws_secretsmanager_secret.app_user[0].arn : null
}

output "app_user_secret_name" {
  description = "Name of the Secrets Manager secret containing app_user credentials"
  value       = var.db_schema != "public" ? aws_secretsmanager_secret.app_user[0].name : null
}

output "app_username" {
  description = "The database username for the schema-scoped app_user"
  value       = var.db_schema != "public" ? "app_user_${var.db_schema}" : null
}
