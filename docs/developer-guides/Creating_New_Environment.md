# Creating a New Development Environment

This guide walks through the steps to create a new environment (e.g. `dev2`, `staging`, `test`) for the NHS HomeTest Service.

## Overview

Each environment deploys its own isolated set of:

- Lambda functions (hello-world, eligibility-test-info, order-router, order-router-sh24)
- API Gateway (REST API with per-lambda path routing)
- CloudFront distribution + S3 bucket (Next.js SPA)
- SQS queues (for async order processing)
- Route53 DNS record (`{env}.hometest.service.nhs.uk`)

All environments share core infrastructure (VPC, WAF, ACM, KMS, Cognito, RDS) deployed under `poc/core/`.

## Prerequisites

- Core infrastructure already deployed (`network`, `shared_services`, `aurora-postgres`, `lambda-goose-migrator`)
- AWS SSO access configured (`aws sso login --profile Admin-PoC`)
- Terraform >= 1.14.0 and Terragrunt >= 0.99.0 installed (run `mise install`)
- The `hometest-service` repo cloned alongside this repo (for Lambda and SPA source code)

```text
parent-dir/
├── hometest-mgmt-terraform/   (this repo)
└── hometest-service/           (application code)
    ├── lambdas/
    └── ui/
```

## Step-by-Step Guide

### Step 1: Create the Environment Directory

Create a new directory under `infrastructure/environments/poc/` with your environment name:

```bash
ENV_NAME="dev2"  # Change this to your desired environment name
mkdir -p infrastructure/environments/poc/${ENV_NAME}/hometest-app
```

### Step 2: Create `env.hcl`

Create `infrastructure/environments/poc/${ENV_NAME}/env.hcl` with the environment name:

```hcl
# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  environment = "dev2"  # Must match the directory name
}
```

The `environment` value is used for:

- Terraform state key: `nhs-hometest-poc-{environment}-hometest-app.tfstate`
- Resource naming: `nhs-hometest-{environment}-*`
- DNS: `{environment}.hometest.service.nhs.uk`
- Resource tagging: `Environment = "{environment}"`

### Step 3: Create `hometest-app/terragrunt.hcl`

Create `infrastructure/environments/poc/${ENV_NAME}/hometest-app/terragrunt.hcl`.

Copy from the `dev` environment as a starting point:

```bash
cp infrastructure/environments/poc/dev/hometest-app/terragrunt.hcl \
   infrastructure/environments/poc/${ENV_NAME}/hometest-app/terragrunt.hcl
```

Then edit the file to update environment-specific values.

### Step 4: Customise the Terragrunt Configuration

The new `terragrunt.hcl` will inherit most settings from `_envcommon/hometest-app.hcl` automatically. You only need to update values that differ from the `dev` environment.

#### 4a. Update the Header Comment

```hcl
# TERRAGRUNT CONFIGURATION FOR dev2 ENVIRONMENT
# Deployment with: cd dev2/hometest-app && terragrunt apply
```

#### 4b. Update Secrets ARNs

Create environment-specific secrets in AWS Secrets Manager, then update the `lambda_secrets_arns`:

```hcl
lambda_secrets_arns = [
  dependency.rds_postgres.outputs.db_instance_master_user_secret_arn,
  "arn:aws:secretsmanager:eu-west-2:781863586270:secret:nhs-hometest/dev2/preventex-client-secret-*",
  "arn:aws:secretsmanager:eu-west-2:781863586270:secret:nhs-hometest/dev2/sh24-client-secret-*"
]
```

#### 4c. Update Lambda Environment Variables

Update supplier URLs, client IDs, and secret names for each Lambda that connects to external services:

```hcl
# order-router-lambda
environment = {
  NODE_OPTIONS                = "--enable-source-maps"
  ENVIRONMENT                 = include.envcommon.locals.environment
  SUPPLIER_BASE_URL           = "https://func-nhshometest-dev2.azurewebsites.net/"
  SUPPLIER_CLIENT_ID          = "<your-client-id>"
  SUPPLIER_CLIENT_SECRET_NAME = "nhs-hometest/dev2/preventex-client-secret"
  # ... other vars
}
```

#### 4d. Optional: Override Source Paths

By default, Lambda and SPA code is sourced from `../hometest-service/`. To use a different source (e.g. a feature branch build), add overrides to `env.hcl`:

```hcl
locals {
  environment = "dev2"

  # Optional: override source paths (defaults come from _envcommon/hometest-app.hcl)
  # lambdas_source_dir = "/path/to/custom/lambdas"
  # spa_source_dir     = "/path/to/custom/ui"
  # spa_type           = "vite"  # "nextjs" (default) or "vite"
}
```

#### 4e. Optional: Use Placeholder Lambdas

To deploy infrastructure without real Lambda code (useful for testing infrastructure changes):

```hcl
use_placeholder_lambda = true
```

### Step 5: Create AWS Secrets

Before deploying, create the required secrets in AWS Secrets Manager:

```bash
# Create supplier client secrets for the new environment
aws secretsmanager create-secret \
  --name "nhs-hometest/dev2/preventex-client-secret" \
  --description "Preventex supplier client secret for dev2" \
  --secret-string '{"client_secret":"YOUR_SECRET_VALUE"}' \
  --region eu-west-2

aws secretsmanager create-secret \
  --name "nhs-hometest/dev2/sh24-client-secret" \
  --description "SH24 supplier client secret for dev2" \
  --secret-string '{"client_secret":"YOUR_SECRET_VALUE"}' \
  --region eu-west-2
```

### Step 6: Validate the Configuration

```bash
cd infrastructure/environments/poc/${ENV_NAME}/hometest-app

# Validate the Terragrunt config
terragrunt validate

# Preview what will be created
terragrunt plan
```

### Step 7: Deploy

```bash
cd infrastructure/environments/poc/${ENV_NAME}/hometest-app
terragrunt apply
```

This will:

1. Build Lambda functions from `hometest-service/lambdas/` (via `build_lambdas` hook)
2. Build the Next.js SPA from `hometest-service/ui/` (via `build_spa` hook)
3. Create all AWS resources (Lambda, API Gateway, CloudFront, S3, SQS, Route53)
4. Upload the SPA to S3 and invalidate CloudFront cache (via `upload_spa` hook)

### Step 8: Verify the Deployment

After successful apply, Terraform outputs will show:

```bash
# Check the outputs
terragrunt output

# Key outputs:
# spa_url              = "https://dev2.hometest.service.nhs.uk"
# api_urls             = { "hello-world-lambda" = "https://...", ... }
# cloudfront_id        = "E1234567890ABC"
# lambda_function_names = ["nhs-hometest-dev2-hello-world-lambda", ...]
```

Test the deployment:

```bash
# Health check
curl https://dev2.hometest.service.nhs.uk/hello-world/

# SPA
curl -I https://dev2.hometest.service.nhs.uk/
```

## File Structure After Creation

```text
infrastructure/environments/poc/
├── core/                        # Shared (already deployed)
│   ├── bootstrap/
│   ├── network/
│   ├── shared_services/
│   ├── aurora-postgres/
│   └── lambda-goose-migrator/
├── dev/                         # Existing environment
│   ├── env.hcl
│   └── hometest-app/
│       └── terragrunt.hcl
└── dev2/                        # ← New environment
    ├── env.hcl
    └── hometest-app/
        └── terragrunt.hcl
```

## How It Works

The Terragrunt configuration chain:

1. **`env.hcl`** — Sets `environment = "dev2"` (consumed by all parent configs)
2. **`terragrunt.hcl`** includes:
   - `root.hcl` — S3 backend config, tags (state key uses `{environment}`)
   - `_envcommon/hometest-app.hcl` — Shared defaults, build hooks, source paths
3. **Dependencies** (`network`, `shared_services`, `aurora-postgres`) — Read outputs from core via `dependency` blocks with mock outputs for plan/validate
4. **`inputs`** — Environment-specific values override the shared defaults

The state file will be stored at:

```text
s3://nhs-hometest-poc-core-s3-tfstate/nhs-hometest-poc-dev2-hometest-app.tfstate
```

## Destroying an Environment

To tear down an environment completely:

```bash
cd infrastructure/environments/poc/${ENV_NAME}/hometest-app
terragrunt destroy
```

The `empty_spa_bucket_on_destroy` hook will automatically clean all versioned objects from the S3 SPA bucket before Terraform attempts to delete it.

After destroying infrastructure, clean up secrets:

```bash
aws secretsmanager delete-secret \
  --secret-id "nhs-hometest/dev2/preventex-client-secret" \
  --force-delete-without-recovery \
  --region eu-west-2

aws secretsmanager delete-secret \
  --secret-id "nhs-hometest/dev2/sh24-client-secret" \
  --force-delete-without-recovery \
  --region eu-west-2
```

## Checklist

- [ ] Created `infrastructure/environments/poc/{env}/env.hcl`
- [ ] Created `infrastructure/environments/poc/{env}/hometest-app/terragrunt.hcl`
- [ ] Updated header comments with correct environment name
- [ ] Created environment-specific secrets in AWS Secrets Manager
- [ ] Updated `lambda_secrets_arns` with correct secret ARNs
- [ ] Updated supplier environment variables (URLs, client IDs, secret names)
- [ ] Ran `terragrunt validate` successfully
- [ ] Ran `terragrunt plan` and reviewed changes
- [ ] Ran `terragrunt apply` successfully
- [ ] Verified SPA loads at `https://{env}.hometest.service.nhs.uk`
- [ ] Verified API responds at `https://{env}.hometest.service.nhs.uk/hello-world/`

## Troubleshooting

### "Can't find env.hcl"

Ensure `env.hcl` exists in the environment directory (not inside `hometest-app/`):

```text
poc/{env}/env.hcl              ← correct
poc/{env}/hometest-app/env.hcl ← wrong
```

### DNS not resolving

The wildcard ACM certificate (`*.hometest.service.nhs.uk`) and Route53 zone are shared. CloudFront creates a Route53 alias record automatically. Allow a few minutes for DNS propagation.

### Lambda build failures

Ensure the `hometest-service` repo is cloned and `npm ci` works:

```bash
cd ../hometest-service/lambdas
npm ci
npm run build
```

### State lock errors

Another deployment may be in progress. Check for stale locks:

```bash
terragrunt force-unlock <LOCK_ID>
```
