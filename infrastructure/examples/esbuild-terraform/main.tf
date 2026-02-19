# =============================================================================
# esbuild + Terraform Example
#
# Shows how to use null_resource + archive_file to build and package lambdas
# with change detection — no shell scripts or Terragrunt hooks needed.
#
# The key insight: Terraform's archive_file creates the zip, and
# null_resource triggers esbuild only when source files change.
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "lambdas_source_dir" {
  description = "Path to the lambdas source directory (e.g., ../hometest-service/lambdas)"
  type        = string
}

variable "lambda_names" {
  description = "List of lambda directory names to build"
  type        = list(string)
  default = [
    "eligibility-test-info-lambda",
    "order-router-lambda",
    "login-lambda",
    "order-result-lambda",
  ]
}

# =============================================================================
# SOURCE HASH — Detects when source code changes
#
# Uses a hash of all TypeScript source files + config files.
# When the hash changes, the null_resource triggers a rebuild.
# =============================================================================

locals {
  src_dir  = "${var.lambdas_source_dir}/src"
  dist_dir = "${var.lambdas_source_dir}/dist"

  # Collect all TypeScript source files for hashing
  # This replaces the 60-line calculate_source_hash() function in build-lambdas.sh
  source_files = fileset(local.src_dir, "**/*.ts")
  config_files = toset([
    for f in ["package.json", "package-lock.json", "tsconfig.json"] :
    f if fileexists("${var.lambdas_source_dir}/${f}")
  ])

  # Combined hash of all source + config files
  source_hash = sha256(join("", concat(
    [for f in sort(tolist(local.source_files)) : filesha256("${local.src_dir}/${f}")],
    [for f in sort(tolist(local.config_files)) : filesha256("${var.lambdas_source_dir}/${f}")],
  )))
}

# =============================================================================
# BUILD STEP — Runs esbuild only when source changes
#
# This replaces:
#   - Terragrunt before_hook "build_lambdas"
#   - scripts/build-lambdas.sh (337 lines)
#   - .lambda-build-cache/ hash files
# =============================================================================

resource "null_resource" "lambda_build" {
  # Only re-run when source code actually changes
  triggers = {
    source_hash = local.source_hash
  }

  provisioner "local-exec" {
    working_dir = var.lambdas_source_dir
    command     = "npm ci --silent && npm run build"
  }
}

# =============================================================================
# PACKAGING — Terraform creates zips from esbuild output
#
# This replaces:
#   - The zip loop in build-lambdas.sh
#   - scripts/package.ts (archiver-based zip)
#   - The .zip files committed inside src/<lambda>/
#
# archive_file creates a deterministic zip from the dist/ output.
# Terraform tracks the hash — if the zip changes, Lambda is redeployed.
# =============================================================================

data "archive_file" "lambda" {
  for_each = toset(var.lambda_names)

  type        = "zip"
  source_file = "${local.dist_dir}/${each.key}/index.js"
  output_path = "${local.dist_dir}/${each.key}.zip"

  depends_on = [null_resource.lambda_build]
}

# =============================================================================
# OUTPUTS — Use these in your aws_lambda_function resource
# =============================================================================

output "lambda_packages" {
  description = "Map of lambda name -> zip path and hash for use in aws_lambda_function"
  value = {
    for name, archive in data.archive_file.lambda : name => {
      zip_path         = archive.output_path
      source_code_hash = archive.output_base64sha256
      output_size      = archive.output_size
    }
  }
}

# =============================================================================
# EXAMPLE: How to use with aws_lambda_function
# =============================================================================

# resource "aws_lambda_function" "this" {
#   for_each = data.archive_file.lambda
#
#   function_name    = each.key
#   role             = aws_iam_role.lambda.arn
#   handler          = "index.handler"
#   runtime          = "nodejs24.x"
#   filename         = each.value.output_path
#   source_code_hash = each.value.output_base64sha256
#
#   environment {
#     variables = {
#       NODE_OPTIONS = "--enable-source-maps"
#     }
#   }
# }

# =============================================================================
# COMPARISON: Current vs This Approach
# =============================================================================
#
# CURRENT (build-lambdas.sh):
#   Change detection: Shell script hashes files → compares to .lambda-build-cache/lambdas.hash
#   Build:            npm run build (esbuild via scripts/build.ts)
#   Zip:              Shell `zip -r` loop or scripts/package.ts (archiver)
#   Deploy trigger:   filebase64sha256() on pre-built zip in src/<lambda>/
#
# THIS APPROACH:
#   Change detection: Terraform filesha256() on source files → null_resource triggers
#   Build:            npm ci + npm run build (same esbuild via scripts/build.ts)
#   Zip:              data.archive_file (Terraform-native, deterministic)
#   Deploy trigger:   archive_file.output_base64sha256 (Terraform tracks automatically)
#
# Key difference: Terraform owns the entire lifecycle — no external cache files,
# no shell scripts, no zip files checked into source control.
