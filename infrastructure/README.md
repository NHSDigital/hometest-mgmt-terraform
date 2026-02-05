# NHS HomeTest Infrastructure

This repository contains Terraform infrastructure code with Terragrunt for managing multi-environment deployments of the NHS HomeTest Service.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CORE INFRASTRUCTURE                                    │
│  (Deployed once, shared across all environments)                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│  network/           │  shared_services/                                         │
│  ├─ VPC            │  ├─ KMS Key (encryption)                                  │
│  ├─ Subnets        │  ├─ WAF Regional (API Gateway)                            │
│  ├─ Security Groups│  ├─ WAF CloudFront (SPAs)                                 │
│  ├─ Route53 Zone   │  ├─ ACM Certificates (wildcard)                           │
│  └─ NAT Gateway    │  ├─ Deployment Artifacts S3                               │
│                    │  └─ Developer IAM Role                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PER-ENVIRONMENT RESOURCES                              │
│  (hometest-app - deployed per environment: dev, dev1, dev2, etc.)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                              CloudFront + S3                                     │
│  ui.{env}.hometest.service.nhs.uk  ───►  S3 Bucket (SPA)                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│  api1.{env}.hometest.service.nhs.uk ───► API Gateway 1 ───► Lambda (Users)     │
│  api2.{env}.hometest.service.nhs.uk ───► API Gateway 2 ───► Lambda (Orders)    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Environments

| Environment | UI URL | API 1 URL | API 2 URL |
|-------------|--------|-----------|-----------|
| dev | ui.dev.hometest.service.nhs.uk | api1.dev.hometest.service.nhs.uk | api2.dev.hometest.service.nhs.uk |
| dev1 | ui.dev1.hometest.service.nhs.uk | api1.dev1.hometest.service.nhs.uk | api2.dev1.hometest.service.nhs.uk |
| dev2 | ui.dev2.hometest.service.nhs.uk | api1.dev2.hometest.service.nhs.uk | api2.dev2.hometest.service.nhs.uk |

## Directory Structure

```
infrastructure/
├── environments/
│   ├── _envcommon/
│   │   ├── all.hcl                     # Global configuration
│   │   └── hometest-app.hcl            # Default hometest-app settings
│   ├── root.hcl                        # Root Terragrunt config
│   └── poc/
│       ├── account.hcl                 # AWS account settings
│       ├── core/
│       │   ├── env.hcl
│       │   ├── network/                # VPC, Route53, Security Groups
│       │   │   └── terragrunt.hcl
│       │   └── shared_services/        # WAF, ACM, KMS, S3
│       │       └── terragrunt.hcl
│       ├── dev/
│       │   ├── env.hcl
│       │   └── hometest-app/
│       │       └── terragrunt.hcl
│       ├── dev1/
│       │   ├── env.hcl
│       │   └── hometest-app/
│       │       └── terragrunt.hcl
│       └── dev2/
│           ├── env.hcl
│           └── hometest-app/
│               └── terragrunt.hcl
├── modules/
│   ├── api-gateway/                    # API Gateway with custom domain
│   ├── cloudfront-spa/                 # CloudFront + S3 for SPA
│   ├── lambda/                         # Lambda function
│   └── lambda-iam/                     # Lambda execution role
└── src/
    ├── network/                        # VPC, subnets, Route53
    ├── shared_services/                # WAF, ACM, KMS, S3
    └── hometest-app/                   # Per-environment app
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.5.0
3. **Terragrunt** >= 0.50.0
4. **Node.js** >= 20.x (for building Lambda functions and SPA)

## Deployment Order

### 1. Deploy Core Infrastructure (Once)

```bash
# Deploy network first (VPC, Route53, Security Groups)
cd infrastructure/environments/poc/core/network
terragrunt apply

# Deploy shared services (WAF, ACM, KMS)
cd infrastructure/environments/poc/core/shared_services
terragrunt apply
```

### 2. Deploy Environments

```bash
# Deploy a specific environment
cd infrastructure/environments/poc/dev1/hometest-app
terragrunt apply

# Or deploy all app environments at once
cd infrastructure/environments/poc
terragrunt run-all apply --terragrunt-include-dir "*/hometest-app"
```

## Dependencies

The hometest-app deployments depend on outputs from:

| Dependency | Outputs Used |
|------------|--------------|
| **network** | `vpc_id`, `private_subnet_ids`, `lambda_security_group_id`, `route53_zone_id` |
| **shared_services** | `kms_key_arn`, `waf_regional_arn`, `waf_cloudfront_arn`, `acm_*_certificate_arn`, `deployment_artifacts_bucket_*` |

## Shared vs Per-Environment Resources

### Shared (in `core/`)

| Resource | Why Shared |
|----------|------------|
| **VPC & Subnets** | Same network for all environments |
| **KMS Key** | Single key simplifies management |
| **WAF Web ACLs** | Consistent security rules |
| **ACM Certificates** | Wildcard covers all subdomains |
| **Deployment S3** | Centralized artifact storage |
| **Developer IAM** | Single role for all deployments |

### Per-Environment (in `{env}/hometest-app/`)

| Resource | Why Per-Environment |
|----------|---------------------|
| **Lambda Functions** | Different code versions per env |
| **API Gateways** | Separate endpoints per env |
| **CloudFront** | Separate SPA distributions |
| **Route53 Records** | Environment-specific DNS |

## Security Features

### Network Security
- **VPC** with private subnets for Lambda
- **Security Groups** with least-privilege rules
- **NAT Gateway** for outbound internet access

### WAF Protection
- AWS Managed Rules (CommonRuleSet, SQLi, KnownBadInputs)
- Rate limiting (2000 requests/5 min per IP)
- Separate WAFs for API Gateway and CloudFront

### Encryption
- **KMS** encryption for Lambda env vars, S3, CloudWatch
- **TLS 1.2+** for all endpoints
- **HTTPS only** with HTTP redirect

### Access Control
- **MFA required** for developer role (production)
- **IP restrictions** available
- **Explicit denies** for dangerous actions

## Outputs

After deploying hometest-app, you get:

| Output | Description |
|--------|-------------|
| `api1_url` | API 1 endpoint URL |
| `api2_url` | API 2 endpoint URL |
| `spa_url` | SPA frontend URL |
| `cloudfront_distribution_id` | For cache invalidation |
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
