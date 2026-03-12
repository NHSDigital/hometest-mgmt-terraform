# NHS HomeTest Infrastructure

This repository contains Terraform infrastructure code with Terragrunt for managing multi-environment deployments of the NHS HomeTest Service.

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           BOOTSTRAP (deployed manually once)                     │
│  bootstrap/                                                                      │
│  ├─ S3 Backend (terraform state)      ├─ GitHub OIDC IAM Role                   │
│  ├─ KMS Key (state encryption)        ├─ Permissions Boundary                   │
│  └─ Access Logging S3 Bucket          └─ Region Opt-in Controls                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CORE INFRASTRUCTURE                                    │
│  (Deployed once, shared across all environments)                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│  network/                │  shared_services/                                    │
│  ├─ VPC                  │  ├─ KMS Key (encryption)                             │
│  ├─ Subnets (pub/priv/   │  ├─ WAF Regional (API Gateway)                      │
│  │  data)                │  ├─ WAF CloudFront (SPAs)                            │
│  ├─ Security Groups      │  ├─ ACM Certificates (wildcard)                      │
│  ├─ NAT Gateways         │  ├─ Cognito User Pool + Identity Pool                │
│  ├─ Network Firewall     │  └─ Developer IAM Role                               │
│  ├─ VPC Endpoints        │                                                      │
│  ├─ VPC Flow Logs        │  aurora-postgres/                                    │
│  ├─ Route53 (public +    │  ├─ Aurora PostgreSQL Serverless v2                  │
│  │  private zones, DNSSEC│  └─ Security Group (CIDR + SG rules)                 │
│  │  DNS query logging)   │                                                      │
│  └─ NACLs                │  lambda-goose-migrator/                              │
│                          │  └─ Goose database migrations                        │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PER-ENVIRONMENT RESOURCES                              │
│  (hometest-app — deployed per environment: dev, etc.)                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│  CloudFront + S3 (SPA)                                                          │
│  {env}.hometest.service.nhs.uk ───► S3 Bucket (Next.js SPA)                    │
│                                                                                  │
│  API Gateway (REST)                                                              │
│  /hello-world/*  ───► hello-world-lambda                                        │
│  /test-order/*   ───► eligibility-test-info-lambda                              │
│                                                                                  │
│  SQS Queues                                                                      │
│  order-router-lambda       ◄── SQS (Preventex supplier)                         │
│  order-router-lambda-sh24  ◄── SQS (SH24 supplier)                             │
│                                                                                  │
│  Lambda Functions (Node.js 24.x)                                                │
│  ├─ hello-world-lambda              (health check)                              │
│  ├─ eligibility-test-info-lambda    (test eligibility, DB access)               │
│  ├─ order-router-lambda             (async order processing — Preventex)        │
│  └─ order-router-lambda-sh24        (async order processing — SH24)             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```text
infrastructure/
├── environments/
│   ├── _envcommon/
│   │   ├── all.hcl                     # Global config (region, project, GitHub, Cognito)
│   │   └── hometest-app.hcl            # Shared hometest-app settings + build hooks
│   ├── root.hcl                        # Root Terragrunt config (S3 backend, tags)
│   └── poc/
│       ├── account.hcl                 # AWS account settings (781863586270)
│       ├── terragrunt.hcl              # POC account coordination (skip=true)
│       ├── core/
│       │   ├── env.hcl                 # environment = "core"
│       │   ├── bootstrap/              # S3 state backend, GitHub OIDC
│       │   │   └── terragrunt.hcl
│       │   ├── network/                # VPC, Route53, Firewall, Endpoints
│       │   │   └── terragrunt.hcl
│       │   ├── shared_services/        # WAF, ACM, KMS, Cognito, IAM
│       │   │   └── terragrunt.hcl
│       │   ├── aurora-postgres/        # Aurora PostgreSQL Serverless v2
│       │   │   └── terragrunt.hcl
│       │   └── lambda-goose-migrator/  # Database migrations
│       │       └── terragrunt.hcl
│       └── dev/
│           ├── env.hcl                 # environment = "dev"
│           └── hometest-app/           # Lambda, API GW, CloudFront, SQS
│               └── terragrunt.hcl
├── modules/                            # Reusable Terraform modules
│   ├── api-gateway/                    # API Gateway REST API with custom domain
│   ├── cloudfront-spa/                 # CloudFront + S3 for SPA with routing
│   ├── deployment-artifacts/           # S3 bucket for Lambda packages
│   ├── developer-iam/                  # Developer deploy role with scoped policies
│   ├── lambda/                         # Lambda function with placeholder support
│   ├── lambda-goose-migrator/          # Goose database migrator Lambda
│   ├── lambda-iam/                     # Lambda execution role + policies
│   ├── aurora-postgres/                # Aurora PostgreSQL via community module
│   ├── sqs/                            # SQS queues with DLQ
│   └── waf/                            # WAFv2 Web ACL with managed rules
└── src/                                # Terraform root modules (composed from modules/)
    ├── bootstrap/                      # State backend + GitHub OIDC bootstrap
    ├── network/                        # VPC, subnets, firewall, Route53, endpoints
    ├── shared_services/                # WAF, ACM, KMS, Cognito, IAM
    ├── aurora-postgres/                # Aurora PostgreSQL Serverless v2 instance
    └── hometest-app/                   # Per-environment app (Lambda, API GW, CF, SQS)
```

## Prerequisites

| Tool | Required Version | Purpose |
|------|-----------------|---------|
| **Terraform** | >= 1.14.0 | Infrastructure provisioning |
| **Terragrunt** | >= 0.99.0 | DRY multi-environment configuration |
| **AWS CLI** | >= 2.x | AWS interaction |
| **Node.js** | >= 20.x | Building Lambda functions and SPA |
| **mise** | latest | Tool version management (see `.mise.toml`) |

Install pinned versions via mise:

```bash
mise install
```

## Deployment Order

### 0. Bootstrap (First Time Only)

The bootstrap module creates the S3 backend, KMS key, and GitHub OIDC role. It uses local state initially.

```bash
cd infrastructure/src/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

See [bootstrap README](infrastructure/src/bootstrap/README.md) for state migration instructions.

### 1. Deploy Core Infrastructure

```bash
# Network (VPC, Route53, Firewall, NAT, Security Groups, VPC Endpoints)
cd infrastructure/environments/poc/core/network
terragrunt apply

# Shared Services (WAF, ACM, KMS, Cognito, Developer IAM)
cd ../shared_services
terragrunt apply

# Aurora PostgreSQL (depends on network)
cd ../aurora-postgres
terragrunt apply

# Database migrations (depends on aurora-postgres)
cd ../lambda-goose-migrator
terragrunt apply
```

### 2. Deploy Application Environments

```bash
# Deploy dev environment
cd infrastructure/environments/poc/dev/hometest-app
terragrunt apply

# Or deploy everything at once (respects dependency order)
cd infrastructure/environments/poc
terragrunt run-all apply
```

### Adding New Environments

To add a new environment (e.g. `staging`):

1. Create `infrastructure/environments/poc/staging/env.hcl`:

   ```hcl
   locals {
     environment = "staging"
   }
   ```

2. Create `infrastructure/environments/poc/staging/hometest-app/terragrunt.hcl` — copy from `dev/hometest-app/terragrunt.hcl` and adjust environment-specific values.

3. Deploy: `cd staging/hometest-app && terragrunt apply`

## Dependencies

The hometest-app deployments depend on outputs from:

| Dependency | Outputs Used |
|------------|--------------|
| **network** | `vpc_id`, `private_subnet_ids`, `lambda_security_group_id`, `route53_zone_id` |
| **shared_services** | `kms_key_arn`, `waf_cloudfront_arn`, `acm_cloudfront_certificate_arn` |
| **aurora-postgres** | `cluster_endpoint`, `cluster_master_user_secret_arn`, `cluster_database_name`, `cluster_port` |

## Shared vs Per-Environment Resources

### Shared (in `core/`)

| Resource | Why Shared |
|----------|------------|
| **VPC & Subnets** | Same network for all environments |
| **Network Firewall** | Centralized egress filtering |
| **VPC Endpoints** | Shared private connectivity to AWS services |
| **Route53 Zones** | Single DNS zone with DNSSEC |
| **KMS Key** | Single key simplifies management |
| **WAF Web ACLs** | Consistent security rules |
| **ACM Certificates** | Wildcard covers all subdomains |
| **Cognito** | Shared user pool and identity pool |
| **Developer IAM** | Single role for all deployments |
| **Aurora PostgreSQL** | Shared database (POC) |

### Per-Environment (in `{env}/hometest-app/`)

| Resource | Why Per-Environment |
|----------|---------------------|
| **Lambda Functions** | Different code versions per env |
| **API Gateways** | Separate endpoints per env |
| **CloudFront + S3** | Separate SPA distributions per env |
| **SQS Queues** | Separate message queues per env |
| **Route53 Records** | Environment-specific DNS (`{env}.hometest.service.nhs.uk`) |

## Security Features

### Network Security

- **VPC** with public, private, and data subnets
- **Network Firewall** with strict-order stateful rules, domain filtering, and IP filtering
- **NACLs** with port restrictions on private and data subnets
- **Security Groups** with least-privilege rules (Lambda, Lambda-DB, Aurora)
- **NAT Gateways** for outbound internet access from private subnets
- **VPC Endpoints** for private connectivity (S3, Lambda, Secrets Manager, SQS, KMS, etc.)

### WAF Protection

- AWS Managed Rules (CommonRuleSet, SQLi, KnownBadInputs, IP Reputation, Anonymous IP)
- Rate limiting (2000 requests/5 min per IP)
- Geo blocking support
- IP allow list support
- Separate WAFs for API Gateway (regional) and CloudFront (global)
- CloudWatch logging with field redaction

### Encryption

- **KMS** encryption for Lambda env vars, S3, CloudWatch, SQS, state files
- **TLS 1.2+** for all endpoints
- **HTTPS only** with HTTP redirect
- **DNSSEC** on Route53 zones

### Access Control

- **GitHub OIDC** — no long-lived AWS credentials
- **MFA support** for developer role (configurable)
- **Permissions boundaries** to prevent privilege escalation
- **Scoped IAM policies** with explicit denies for dangerous actions

### Database Security

- **VPC-only access** via data subnets
- **Security group** restricting ingress to allowed CIDRs and Lambda SG
- **AWS-managed master user secret** in Secrets Manager
- **Encryption at rest** via KMS

## Outputs

After deploying hometest-app, you get:

| Output | Description |
|--------|-------------|
| `api_urls` | API endpoint URLs per Lambda |
| `spa_url` | SPA frontend URL |
| `cloudfront_distribution_id` | For cache invalidation |
| `lambda_function_names` | Deployed Lambda function names |
| `sqs_queue_urls` | SQS queue URLs for triggered Lambdas |
| `deploy_commands` | Ready-to-use deployment commands |

## Troubleshooting

### Dependencies not resolved

```bash
# Run with explicit dependency fetching
terragrunt apply --terragrunt-fetch-dependency-output-from-state
```

### Certificate validation pending

```bash
# Check certificate status
aws acm describe-certificate --certificate-arn <ARN> --query 'Certificate.Status'
```

### WAF not attached

```bash
# Verify WAF association
aws wafv2 list-resources-for-web-acl --web-acl-arn <ARN> --resource-type API_GATEWAY
```

### Aurora connection issues

```bash
# Check Aurora cluster status
aws rds describe-db-clusters --query 'DBClusters[*].[DBClusterIdentifier,Status]'

# Retrieve master user secret
aws secretsmanager get-secret-value --secret-id <secret-arn>

# Run database migrations manually
cd infrastructure/environments/poc/core/lambda-goose-migrator
terragrunt apply
```

### Lambda build failures

The `hometest-app.hcl` envcommon includes build hooks that run `npm ci` and `npm run build` before Terraform apply. Ensure the `hometest-service` repo is cloned alongside this repo:

```text
parent-dir/
├── hometest-mgmt-terraform/   (this repo)
└── hometest-service/           (application code)
    ├── lambdas/
    └── ui/
```
