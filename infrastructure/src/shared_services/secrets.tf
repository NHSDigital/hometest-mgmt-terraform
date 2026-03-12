################################################################################
# Secrets Manager - Demo Secrets for Lambda Functions
################################################################################

################################################################################
# Example API Secret
################################################################################

resource "aws_secretsmanager_secret" "api_config" {
  name        = "${var.project_name}/${var.environment}/api-config"
  description = "API configuration secrets for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.main.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-config"
  })
}

resource "aws_secretsmanager_secret_version" "api_config" {
  secret_id = aws_secretsmanager_secret.api_config.id
  secret_string = jsonencode({
    api_key       = "demo-api-key-${var.environment}"
    database_host = "db.${var.environment}.internal"
    feature_flags = {
      new_ui_enabled = true
      beta_features  = false
    }
    # In production, these would be actual secrets
    # populated through CI/CD or manual configuration
  })
}

################################################################################
# Outputs
################################################################################

output "api_config_secret_arn" {
  description = "ARN of the API config secret"
  value       = aws_secretsmanager_secret.api_config.arn
}

output "api_config_secret_name" {
  description = "Name of the API config secret"
  value       = aws_secretsmanager_secret.api_config.name
}
