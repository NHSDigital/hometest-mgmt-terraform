# Lambda Goose Migrator Module

A Terraform module that deploys a Go-based AWS Lambda function for running [Goose](https://github.com/pressly/goose) database migrations against PostgreSQL.

## Overview

This module creates a Lambda function that connects to an Aurora PostgreSQL database and runs SQL migrations using the Goose migration tool. The Lambda is compiled from Go source code and runs on the `provided.al2023` custom runtime for optimal performance.

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda Goose Migrator                         │
├─────────────────────────────────────────────────────────────────┤
│  Runtime: provided.al2023 (custom Go binary)                    │
│  Architecture: arm64                                            │
│  Memory: 128 MB                                                 │
│  Timeout: 300s (5 minutes)                                      │
├─────────────────────────────────────────────────────────────────┤
│  Environment Variables:                                         │
│  - DB_USERNAME: Database username                               │
│  - DB_ADDRESS: Database hostname                                │
│  - DB_PORT: Database port                                       │
│  - DB_NAME: Database name                                       │
│  - DB_SECRET_ARN: Secrets Manager ARN for password              │
└─────────────────────────────────────────────────────────────────┘
           │
           │  VPC (private subnets)
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Aurora PostgreSQL                             │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "goose_migrator" {
  source = "../modules/lambda-goose-migrator"

  db_username        = "postgres"
  db_address         = module.aurora.cluster_endpoint
  db_port            = "5432"
  db_name            = "hometest"
  db_cluster_id      = module.aurora.cluster_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.lambda_rds.id]
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `db_username` | Database username | `string` | Yes |
| `db_address` | Database hostname/endpoint | `string` | Yes |
| `db_port` | Database port | `string` | Yes |
| `db_name` | Database name | `string` | Yes |
| `db_cluster_id` | Aurora cluster ID (for secret lookup) | `string` | Yes |
| `subnet_ids` | VPC subnet IDs for Lambda | `list(string)` | Yes |
| `security_group_ids` | Security group IDs for Lambda | `list(string)` | Yes |

## Migrations

SQL migrations are stored in `src/migrations/` using Goose naming conventions:

```text
src/migrations/
├── 000001_create_initial_home_test_tables.sql
└── 000002_seed_home_test_data.sql
```

### Migration Format

```sql
-- +goose Up
CREATE TABLE example (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);

-- +goose Down
DROP TABLE example;
```

### Current Schema

The migrations create the HomeTest service database schema:

| Table | Purpose |
|-------|---------|
| `patient_mapping` | Maps NHS numbers to internal patient UIDs |
| `test_type` | Test type codes and descriptions |
| `supplier` | External supplier configuration (Preventx, SH:24) |
| `la_supplier_offering` | Local Authority → Supplier → Test mappings |
| `test_order` | Test orders with auto-generated references |
| `status_type` | Order status codes |
| `order_status` | Order status history |
| `result_type` | Result codes |
| `result_status` | Test result tracking |

## Invocation

Invoke the Lambda to run pending migrations:

```bash
aws lambda invoke \
  --function-name goose-migrator \
  --payload '{}' \
  response.json
```

## Security

- **VPC Access**: Lambda runs within private subnets
- **Secrets Manager**: Database password retrieved at runtime via `DB_SECRET_ARN`
- **IAM**: Least-privilege role with access to RDS, Secrets Manager, and CloudWatch Logs
- **No hardcoded credentials**: All secrets managed via AWS Secrets Manager

## Build Process

The module uses the `terraform-aws-modules/lambda/aws` module with a custom build step:

1. `go mod tidy` — resolves dependencies
2. Cross-compile for `linux/arm64`
3. Package `bootstrap` binary + `migrations/` folder into ZIP

## Related Modules

- [aurora-postgres](../aurora-postgres/) — Aurora PostgreSQL cluster
- [lambda](../lambda/) — Application Lambda functions
