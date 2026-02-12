# RDS PostgreSQL Module

Terraform module to create an AWS RDS PostgreSQL instance with security group.

## Features

- PostgreSQL RDS instance with configurable version and instance class
- Security group with customizable ingress rules
- Automatic subnet group creation or use existing
- Encryption at rest with KMS support
- Automated backups with configurable retention
- Multi-AZ support for high availability
- Performance Insights and Enhanced Monitoring
- CloudWatch Logs integration
- Secrets Manager integration for password management
- Blue/Green deployment support

## Usage

### Basic Example

```hcl
module "rds_postgres" {
  source = "../../modules/aurora-postgres"

  identifier = "myapp-db"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "myapp"
  username = "dbadmin"

  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "dev"
    Project     = "myapp"
  }
}
```

### Production Example

```hcl
module "rds_postgres" {
  source = "../../modules/aurora-postgres"

  identifier = "myapp-prod-db"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]

  # Production-grade instance
  instance_class        = "db.r6g.xlarge"
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp3"

  # High availability
  multi_az = true

  # Database configuration
  db_name  = "production_db"
  username = "dbadmin"
  manage_master_user_password = true  # Use Secrets Manager

  # Enhanced security
  storage_encrypted = true
  kms_key_id        = "arn:aws:kms:eu-west-2:xxxxx:key/xxxxx"

  # Network access
  allowed_security_group_ids = [
    module.app.security_group_id,
    module.lambda.security_group_id
  ]

  # Backup configuration
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
  skip_final_snapshot    = false
  deletion_protection    = true

  # Monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # Parameter group customization
  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/32768}"
    }
  ]

  tags = {
    Environment = "prod"
    Project     = "myapp"
    Compliance  = "hipaa"
  }
}
```

### With Existing Subnet Group

```hcl
module "rds_postgres" {
  source = "../../modules/aurora-postgres"

  identifier           = "myapp-db"
  vpc_id              = "vpc-xxxxx"
  db_subnet_group_name = "existing-db-subnet-group"

  allowed_cidr_blocks = ["10.0.0.0/16"]

  tags = {
    Environment = "dev"
  }
}
```

## Outputs

- `db_instance_endpoint` - Database connection endpoint
- `db_instance_address` - Database hostname
- `db_instance_port` - Database port
- `db_instance_master_user_secret_arn` - ARN of master password secret in Secrets Manager
- `security_group_id` - Security group ID for the database
- `connection_string` - PostgreSQL connection string (without password)

## Password Management

By default, the module uses AWS Secrets Manager to manage the master password (`manage_master_user_password = true`). You can retrieve the password using:

```bash
aws secretsmanager get-secret-value --secret-id <secret-arn> --query SecretString --output text | jq -r .password
```

Alternatively, set `manage_master_user_password = false` and provide your own password via the `password` variable.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| db | terraform-aws-modules/rds/aws | ~> 6.0 |
| security_group | terraform-aws-modules/security-group/aws | ~> 5.0 |
