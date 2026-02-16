# GitHub Copilot Instructions

This repository contains Terraform/Terragrunt infrastructure code for the NHS Hometest service deployed to AWS.

## Project Structure

- `infrastructure/src/` - Terraform root modules (bootstrap, network, aurora-postgres, shared_services, hometest-app)
- `infrastructure/modules/` - Reusable Terraform modules (lambda, api-gateway, aurora-postgres, cloudfront-spa, sqs, waf, etc.)
- `infrastructure/environments/` - Terragrunt environment configurations (poc/core, poc/dev)
- `scripts/` - Shell scripts for testing, Docker, and automation
- `.github/workflows/` - GitHub Actions CI/CD pipelines
- `.github/actions/` - Reusable GitHub Actions

## Technology Stack

- **IaC**: Terraform 1.14+, Terragrunt 0.99+
- **Cloud**: AWS (Lambda, API Gateway, Aurora PostgreSQL, CloudFront, SQS, WAF)
- **CI/CD**: GitHub Actions
- **Tool Management**: mise (asdf-compatible)
- **Security Scanning**: Trivy, Checkov, Gitleaks, TFLint
- **Database Migrations**: Goose (pressly/goose)
- **Pre-commit**: Various hooks for linting, formatting, and security

## Code Style Guidelines

### Terraform

- Use `terraform fmt` for formatting
- Follow AWS provider naming conventions
- Use snake_case for resource names and variables
- Include descriptions for all variables and outputs
- Tag all AWS resources with standard tags (environment, project, managed_by)
- Use modules from `infrastructure/modules/` for reusable components

### Terragrunt

- Keep DRY with `root.hcl` includes
- Use `dependency` blocks for cross-module references
- Validate inputs with `terragrunt_validate_inputs`

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Pass shellcheck with severity=warning
- Use functions for reusable code
- Include usage documentation in script headers

### GitHub Actions

- Quote all shell variables: `"$GITHUB_OUTPUT"`, `"$GITHUB_STEP_SUMMARY"`
- Use grouped redirects: `{ echo "..."; } >> "$GITHUB_OUTPUT"`
- Use parameter expansion over sed: `${GITHUB_REF#refs/heads/}`
- Use `jdx/mise-action@v3` for tool installation
- Define inputs for reusable workflows

## Security Considerations

- Never commit secrets or credentials
- Use AWS IAM roles with OIDC for GitHub Actions
- Run Trivy, Checkov, and Gitleaks in pre-commit
- Use `.gitleaksignore` for false positives
- Follow NHS security guidelines

## Testing

- Pre-commit hooks run on every commit
- Goose migrations tested against PostgreSQL in Docker
- Terraform plan runs on PRs for all modules
- Use `mise run test-migrations` to test DB migrations locally

## Common Commands

```bash
# Install tools
mise install

# Run pre-commit
mise run pre-commit

# Test DB migrations
mise run test-migrations

# Terraform operations (via Terragrunt)
cd infrastructure/environments/poc/dev/hometest-app
terragrunt plan
terragrunt apply
```

## AWS Configuration

- Region: eu-west-2 (London)
- Authentication: AWS SSO with OIDC
- Profile: Admin-PoC

## Files to Reference

- `.mise.toml` - Tool versions and tasks
- `.pre-commit-config.yaml` - Pre-commit hook configuration
- `.tflint.hcl` - TFLint rules
- `.checkov.yaml` - Checkov security scanning config
- `trivy.yaml` - Trivy security scanning config
