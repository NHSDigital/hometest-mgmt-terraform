# HomeTest Infrastructure - Environment Deployment Guide

This document provides comprehensive guidance for deploying and managing isolated application environments using Terragrunt.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Environment Structure](#environment-structure)
- [Quick Start](#quick-start)
- [Creating a New Environment](#creating-a-new-environment)
- [Deployment Guide](#deployment-guide)
- [Lambda Artifact Management](#lambda-artifact-management)
- [IAM and Access Control](#iam-and-access-control)
- [Domain and SSL Configuration](#domain-and-ssl-configuration)
- [Teardown Guide](#teardown-guide)
- [Troubleshooting](#troubleshooting)

## Overview

The HomeTest infrastructure uses **Terragrunt** to manage multiple isolated environments (dev, feature branches, staging, prod) with minimal configuration changes. Each environment gets its own:

- Lambda function(s) with dedicated execution role
- API Gateway with mTLS support
- WAF Web ACL for security
- ACM certificate and Route53 DNS records
- CloudWatch logs and monitoring
- Scoped IAM developer role for access control

### Naming Convention

All resources follow the NHS naming schema:

```text
{project_name}-{account_shortname}-{environment}-{component}
```

Example: `nhs-hometest-poc-dev-api`

## Architecture

```text
                                     ┌─────────────────┐
                                     │   Route 53      │
                                     │ hometest.service│
                                     │   .nhs.uk       │
                                     └────────┬────────┘
                                              │
                                              ▼
                                     ┌─────────────────┐
                                     │  ACM Certificate│
                                     │ (SSL/TLS)       │
                                     └────────┬────────┘
                                              │
                                              ▼
                               ┌──────────────────────────┐
                               │      WAF Web ACL         │
                               │ (Rate Limiting, Rules)   │
                               └────────────┬─────────────┘
                                            │
                                            ▼
                               ┌──────────────────────────┐
                               │    API Gateway           │
                               │ (mTLS, Custom Domain)    │
                               └────────────┬─────────────┘
                                            │
                                            ▼
                               ┌──────────────────────────┐
                               │    Lambda Function       │
                               │ (Application Code)       │
                               └────────────┬─────────────┘
                                            │
                           ┌────────────────┼────────────────┐
                           ▼                ▼                ▼
                    ┌──────────┐     ┌──────────┐     ┌──────────┐
                    │   RDS    │     │ Secrets  │     │   S3     │
                    │ Database │     │ Manager  │     │ Buckets  │
                    └──────────┘     └──────────┘     └──────────┘
```

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.14 | `brew install terraform` |
| Terragrunt | >= 0.97 | `brew install terragrunt` |
| AWS CLI | >= 2.0 | `brew install awscli` |

### AWS Configuration

1. Configure AWS SSO:

```bash
aws configure sso

# Add to ~/.aws/config:
[profile Admin-PoC]
sso_session = nhs
sso_account_id = 781863586270
sso_role_name = Admin
region = eu-west-2

[sso-session nhs]
sso_start_url = https://d-9c67018f89.awsapps.com/start/#
sso_region = eu-west-2
sso_registration_scopes = sso:account:access
```

1. Login to AWS:

```bash
aws sso login --profile Admin-PoC
export AWS_PROFILE=Admin-PoC
```

## Environment Structure

```text
infrastructure/
├── environments/
│   ├── _envcommon/
│   │   └── all.hcl              # Global variables
│   ├── root.hcl                 # Root Terragrunt config
│   └── poc/                     # POC AWS Account
│       ├── account.hcl          # Account-level variables
│       ├── core/                # Shared infrastructure
│       │   ├── env.hcl
│       │   ├── bootstrap/       # State bucket, OIDC
│       │   ├── network/         # VPC, subnets, Route53 zone
│       │   └── rds-postgres/    # Shared database
│       └── dev/                 # Dev environment
│           ├── env.hcl          # Environment variables
│           ├── application/     # Lambda function
│           ├── api-gateway/     # API Gateway with mTLS
│           ├── waf/             # WAF Web ACL
│           ├── dns-certificate/ # ACM cert, Route53 records
│           └── iam-developer-role/  # Developer IAM role
└── src/                         # Terraform modules
    ├── api-gateway/
    ├── application/
    ├── dns-certificate/
    ├── iam-developer-role/
    ├── network/
    ├── rds-postgres/
    └── waf/
```

## Quick Start

### Deploy the Dev Environment

```bash
# 1. Ensure AWS credentials are configured
aws sso login --profile Admin-PoC
export AWS_PROFILE=Admin-PoC

# 2. Initialize and plan
make tf-init ENV=dev
make tf-plan ENV=dev

# 3. Apply changes
make tf-apply ENV=dev

# 4. Verify deployment
make test-api ENV=dev
```

### Deploy a Specific Module

```bash
# Deploy only the Lambda function
make deploy-application ENV=dev

# Deploy only API Gateway
make deploy-api-gateway ENV=dev

# Deploy only WAF
make deploy-waf ENV=dev
```

## Creating a New Environment

### Option 1: Using Make Target (Recommended)

```bash
# Create a new feature branch environment
make new-env NEW_ENV=feature-login

# Customize the environment
vim infrastructure/environments/poc/feature-login/env.hcl

# Deploy
make tf-apply ENV=feature-login
```

### Option 2: Manual Creation

1. Create the environment directory:

```bash
mkdir -p infrastructure/environments/poc/feature-xyz
```

1. Create `env.hcl`:

```hcl
# infrastructure/environments/poc/feature-xyz/env.hcl
locals {
  environment = "feature-xyz"
}
```

1. Copy module configurations from dev:

```bash
cp -r infrastructure/environments/poc/dev/* \
      infrastructure/environments/poc/feature-xyz/
```

1. Update any environment-specific settings in the copied `terragrunt.hcl` files.

2. Deploy:

```bash
make tf-apply ENV=feature-xyz
```

### Environment-Specific Variables

Each environment's `env.hcl` file sets the `environment` local variable, which is used for:

- Resource naming (e.g., `nhs-hometest-poc-{environment}-api`)
- DNS subdomain (e.g., `{environment}.hometest.service.nhs.uk`)
- IAM permission scoping

## Deployment Guide

### Deployment Order

For a new environment, deploy in this order:

1. **dns-certificate** - ACM certificate and DNS validation
2. **application** - Lambda function and artifacts bucket
3. **api-gateway** - API Gateway with mTLS (depends on application and certificate)
4. **waf** - WAF Web ACL (depends on api-gateway)
5. **iam-developer-role** - Developer access role

```bash
# Or deploy all at once (Terragrunt handles dependencies)
make tf-apply ENV=dev
```

### Updating the Application

To update the Lambda function code:

1. Build and package the artifact:

```bash
make package-lambda
```

1. Upload to S3:

```bash
make upload-lambda ENV=dev
```

1. Update the Lambda function:

```bash
make deploy-application ENV=dev
```

### Enabling mTLS

mTLS is initially disabled. To enable:

1. Prepare your CA certificate bundle (PEM format)

2. Update `api-gateway/terragrunt.hcl`:

```hcl
inputs = {
  enable_mtls        = true
  truststore_content = file("path/to/ca-bundle.pem")
  # ... other inputs
}
```

1. Apply changes:

```bash
make deploy-api-gateway ENV=dev
```

## Lambda Artifact Management

### Directory Structure

```text
lambdas/
├── api/                    # Main API Lambda
│   ├── index.js           # Handler
│   ├── package.json
│   └── src/
└── worker/                 # Background worker Lambda
    ├── handler.py
    └── requirements.txt
```

### Build Pipeline

1. **Local Build**:

```bash
make build-lambda
```

1. **Package**:

```bash
make package-lambda
# Creates artifacts/api.zip, artifacts/worker.zip, etc.
```

1. **Upload to S3**:

```bash
make upload-lambda ENV=dev
```

### CI/CD Integration

For GitHub Actions, use the workflow:

```yaml
# .github/workflows/deploy.yml
name: Deploy Lambda

on:
  push:
    branches: [main, develop]
    paths:
      - 'lambdas/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::781863586270:role/nhs-hometest-poc-core-github-oidc
          aws-region: eu-west-2

      - name: Build and deploy
        run: |
          make package-lambda
          make upload-lambda ENV=${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
          make deploy-application ENV=${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
```

## IAM and Access Control

### Developer Role

Each environment has a scoped developer role that allows:

| Permission | Scope |
|------------|-------|
| Lambda (create, update, invoke) | Environment-specific functions only |
| API Gateway (read/write) | Environment-specific APIs only |
| CloudWatch Logs (read) | Environment log groups only |
| CloudTrail (read) | Account-wide (for troubleshooting) |
| S3 (read/write) | Environment artifacts bucket only |
| KMS (encrypt/decrypt) | Environment keys only |

### Assuming the Developer Role

```bash
# Using AWS CLI
aws sts assume-role \
  --role-arn arn:aws:iam::781863586270:role/nhs-hometest-poc-dev-developer-role \
  --role-session-name dev-session

# Using AWS SSO (after AFT integration)
# Role will be available in AWS SSO portal
```

### AFT Integration

The developer role is ready for AWS Account Factory for Terraform (AFT) integration:

1. The role includes `AFTReady = true` tag
2. Trust policy supports external ID for cross-account access
3. Role ARN can be referenced in AFT account requests:

```hcl
# In AFT account request
custom_fields = {
  developer_role_arn = "arn:aws:iam::781863586270:role/nhs-hometest-poc-dev-developer-role"
}
```

## Domain and SSL Configuration

### DNS Hierarchy

```text
hometest.service.nhs.uk              # Base domain (Route53 zone)
├── dev.hometest.service.nhs.uk      # Dev environment
├── staging.hometest.service.nhs.uk  # Staging environment
├── feature-xyz.hometest.service.nhs.uk  # Feature branch
└── (root)                           # Production
```

### Certificate Provisioning

Certificates are automatically provisioned via ACM with DNS validation:

1. `dns-certificate` module creates ACM certificate request
2. Adds CNAME records to Route53 for validation
3. ACM validates and issues certificate
4. `api-gateway` module uses certificate for custom domain

### Exposing the API

After deployment, the API is available at:

- **Dev**: `https://dev.hometest.service.nhs.uk/v1/`
- **Feature**: `https://feature-xyz.hometest.service.nhs.uk/v1/`

## Teardown Guide

### Destroy a Single Environment

```bash
# Preview what will be destroyed
cd infrastructure/environments/poc/feature-xyz
terragrunt run-all plan -destroy

# Destroy (requires confirmation)
make tf-destroy ENV=feature-xyz
```

### Destroy Order

Resources are destroyed in reverse dependency order:

1. WAF
2. API Gateway
3. Application (Lambda)
4. DNS Certificate
5. IAM Developer Role

### Cleanup Orphaned Resources

```bash
# Clean local Terragrunt cache
make clean

# Remove environment directory
rm -rf infrastructure/environments/poc/feature-xyz
```

## Troubleshooting

### Common Issues

#### 1. Certificate Validation Timeout

**Symptom**: `aws_acm_certificate_validation` resource times out

**Solution**: Verify Route53 zone is properly delegated from parent domain

```bash
# Check NS records
dig +short NS hometest.service.nhs.uk
```

#### 2. Lambda Deployment Failed

**Symptom**: Lambda function fails to create/update

**Solution**:

- Ensure artifact exists in S3
- Check execution role permissions
- Verify VPC subnets and security groups

```bash
# Check Lambda logs
make logs ENV=dev
```

#### 3. API Gateway 403 Errors

**Symptom**: API returns 403 Forbidden

**Solution**:

- Check WAF logs for blocked requests
- Verify Lambda permission for API Gateway
- Check mTLS configuration if enabled

#### 4. Terragrunt Dependency Errors

**Symptom**: Dependency not found errors

**Solution**:

```bash
# Clear cache and re-init
make clean
make tf-init ENV=dev
```

### Viewing Logs

```bash
# Lambda logs
make logs ENV=dev

# WAF logs
aws logs tail aws-waf-logs-nhs-hometest-poc-dev --follow

# API Gateway access logs
aws logs tail /aws/api-gateway/nhs-hometest-poc-dev-api/access-logs --follow
```

### Getting Help

- Check the [Makefile](../Makefile) for available commands: `make help`
- Review module documentation in `infrastructure/src/*/README.md`
- Contact the Platform Team for access issues
