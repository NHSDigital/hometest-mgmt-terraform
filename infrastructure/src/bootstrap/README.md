# Bootstrap Module for Terraform/Terragrunt with GitHub Actions

This bootstrap module creates the foundational infrastructure required to run Terraform/Terragrunt from GitHub Actions using OIDC authentication.

## Features

- **S3 Backend** - Versioned, encrypted bucket for Terraform state storage
- **DynamoDB Locking** - State locking to prevent concurrent modifications
- **KMS Encryption** - Customer-managed encryption keys for state at rest
- **GitHub OIDC** - Secure, keyless authentication from GitHub Actions
- **Access Logging** - Optional audit trail for state bucket access
- **Security Best Practices** - TLS enforcement, public access blocking, permissions boundaries

## Security Features

| Feature | Description |
|---------|-------------|
| **OIDC Authentication** | No long-lived AWS credentials stored in GitHub |
| **Branch/Environment Restrictions** | Only specified branches and environments can assume the role |
| **KMS Encryption** | State files encrypted with customer-managed key |
| **Key Rotation** | Automatic annual KMS key rotation enabled |
| **TLS 1.2 Enforcement** | S3 bucket requires TLS 1.2 minimum |
| **Public Access Blocked** | All public access settings blocked on buckets |
| **Deletion Protection** | DynamoDB and S3 have lifecycle protection |
| **Least Privilege IAM** | Scoped permissions for state management |
| **Permissions Boundary** | Optional boundary to prevent privilege escalation |
| **Session Duration** | 1-hour maximum session for GitHub Actions role |

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.5.0
3. AWS account with permissions to create IAM, S3, DynamoDB, and KMS resources

## Usage

### Initial Bootstrap (First Time)

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```hcl
   project_name = "hometest"
   environment  = "mgmt"
   account_name = "hometest-mgmt"
   github_repo  = "your-org/hometest-mgmt-terraform"
   ```

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. Note the outputs for GitHub configuration:
   ```bash
   terraform output gha_oidc_role_arn
   terraform output backend_config_hcl
   ```

5. Add the role ARN to GitHub repository secrets as `AWS_ROLE_ARN`

### Migrating State to S3 Backend

After the initial apply with local state:

1. Uncomment the backend configuration in `providers.tf`
2. Run `terraform init -migrate-state`
3. Confirm the state migration

## GitHub Actions Configuration

Add the following to your workflow:

```yaml
jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # Required for OIDC
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-west-2

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan
```

## Terragrunt Configuration

Create a `terragrunt.hcl` in your root:

```hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "hometest-mgmt-tfstate-ACCOUNT_ID"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "hometest-mgmt-tfstate-lock"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `aws_region` | AWS region for resources | `string` | `"eu-west-2"` | no |
| `project_name` | Project name for resource naming | `string` | n/a | yes |
| `environment` | Environment (mgmt, dev, staging, prod) | `string` | `"mgmt"` | no |
| `account_name` | AWS account name/alias | `string` | n/a | yes |
| `github_repo` | GitHub repository (owner/repo) | `string` | n/a | yes |
| `github_branches` | Allowed branches for OIDC | `list(string)` | `["main", "develop"]` | no |
| `github_environments` | Allowed environments for OIDC | `list(string)` | `["dev", "staging", "prod"]` | no |
| `enable_state_bucket_logging` | Enable S3 access logging | `bool` | `true` | no |
| `state_bucket_retention_days` | Days to retain old state versions | `number` | `90` | no |
| `enable_dynamodb_point_in_time_recovery` | Enable DynamoDB PITR | `bool` | `true` | no |
| `kms_key_deletion_window_days` | KMS key deletion window | `number` | `30` | no |
| `additional_iam_policy_arns` | Additional policies for GHA role | `list(string)` | `[]` | no |
| `tags` | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `state_bucket_name` | S3 bucket name for Terraform state |
| `state_bucket_arn` | S3 bucket ARN |
| `dynamodb_table_name` | DynamoDB table name for state locking |
| `dynamodb_table_arn` | DynamoDB table ARN |
| `kms_key_arn` | KMS key ARN for encryption |
| `kms_key_alias` | KMS key alias |
| `github_oidc_provider_arn` | GitHub OIDC provider ARN |
| `gha_oidc_role_arn` | GitHub Actions role ARN (for GitHub secrets) |
| `gha_oidc_role_name` | GitHub Actions role name |
| `logging_bucket_name` | S3 logging bucket name |
| `backend_config` | Backend configuration object |
| `backend_config_hcl` | Backend configuration in HCL format |

## Extending Permissions

The default IAM policy provides read-only access for Terraform planning. To add write permissions:

1. Edit the `infrastructure_policy` in `iam.tf`
2. Uncomment or add statements for your specific resources
3. Follow least-privilege principles - only grant what's needed

Example for EC2 write access:

```hcl
statement {
  sid    = "EC2WriteAccess"
  effect = "Allow"
  actions = [
    "ec2:RunInstances",
    "ec2:TerminateInstances",
    "ec2:CreateTags"
  ]
  resources = ["*"]
  condition {
    test     = "StringEquals"
    variable = "aws:RequestedRegion"
    values   = ["eu-west-2"]
  }
}
```

## Troubleshooting

### OIDC Authentication Fails

1. Verify the GitHub repo name matches exactly
2. Check branch/environment restrictions
3. Ensure workflow has `id-token: write` permission

### State Lock Issues

1. Check DynamoDB table exists and is accessible
2. Verify KMS key permissions
3. Use `terraform force-unlock <LOCK_ID>` if needed

### Encryption Errors

1. Verify KMS key policy includes the GitHub Actions role
2. Check bucket policy allows encryption operations

## Cost Considerations

- **S3**: ~$0.023/GB/month for storage + request costs
- **DynamoDB**: Pay-per-request, typically < $1/month
- **KMS**: $1/month per CMK + $0.03 per 10,000 requests
- **Total**: Usually < $5/month for typical usage
