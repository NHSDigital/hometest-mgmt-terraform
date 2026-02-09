variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda"
  type        = string
}

variable "db_url" {
  description = "Postgres connection string"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda VPC config"
  type        = list(string)
}
