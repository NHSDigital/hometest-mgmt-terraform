#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Quick Deploy Script
# Rapidly redeploy lambdas, UI, or both to an already-running environment
# without re-evaluating the full Terraform state.
#
# Usage:
#   ./quick-deploy.sh --env <env-name> [--lambdas] [--ui] [--all]
#
# Examples:
#   # Deploy only changed lambdas (fastest — ~30s build + targeted apply)
#   ./quick-deploy.sh --env dev-mikmio --lambdas
#
#   # Deploy only UI (build + S3 sync + CloudFront invalidation, no Terraform)
#   ./quick-deploy.sh --env dev-mikmio --ui
#
#   # Deploy both lambdas and UI
#   ./quick-deploy.sh --env dev-mikmio --all
#
#   # Deploy a single lambda by name
#   ./quick-deploy.sh --env dev-mikmio --lambdas --lambda-name login-lambda
#
#   # Force rebuild even if cache says no changes
#   ./quick-deploy.sh --env dev-mikmio --lambdas --force
#
# Prerequisites:
#   - AWS credentials configured (via SSO / assume-role)
#   - mise installed (for Node.js toolchain)
#   - Environment already deployed via full `terragrunt apply`
# -----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
ENV_NAME=""
DEPLOY_LAMBDAS=false
DEPLOY_UI=false
FORCE_REBUILD=false
SINGLE_LAMBDA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --lambdas)
      DEPLOY_LAMBDAS=true
      shift
      ;;
    --ui)
      DEPLOY_UI=true
      shift
      ;;
    --all)
      DEPLOY_LAMBDAS=true
      DEPLOY_UI=true
      shift
      ;;
    --lambda-name)
      SINGLE_LAMBDA="$2"
      shift 2
      ;;
    --force)
      FORCE_REBUILD=true
      shift
      ;;
    -h|--help)
      head -30 "$0" | tail -25
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$ENV_NAME" ]]; then
  echo "Error: --env is required"
  echo "Usage: $0 --env <env-name> [--lambdas] [--ui] [--all]"
  exit 1
fi

if [[ "$DEPLOY_LAMBDAS" == "false" && "$DEPLOY_UI" == "false" ]]; then
  echo "Error: specify at least one of --lambdas, --ui, or --all"
  exit 1
fi

# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOMETEST_SERVICE_DIR="$(cd "$REPO_ROOT/../hometest-service" && pwd)"
TG_DIR="$REPO_ROOT/infrastructure/environments/poc/hometest-app/$ENV_NAME/app"

if [[ ! -d "$TG_DIR" ]]; then
  echo "Error: Environment directory not found: $TG_DIR"
  echo "Available environments:"
  ls -1 "$REPO_ROOT/infrastructure/environments/poc/hometest-app/" 2>/dev/null | grep -v '^_'
  exit 1
fi

LAMBDAS_SOURCE_DIR="$HOMETEST_SERVICE_DIR/lambdas"
LAMBDAS_BASE_PATH="$LAMBDAS_SOURCE_DIR/src"
SPA_SOURCE_DIR="$HOMETEST_SERVICE_DIR/ui"
SPA_DIST_DIR="$SPA_SOURCE_DIR/out"
LAMBDA_BUILD_CACHE="$REPO_ROOT/.lambda-build-cache"
SPA_BUILD_CACHE="$REPO_ROOT/.spa-build-cache"
AWS_REGION="eu-west-2"

echo "=========================================="
echo "Quick Deploy: $ENV_NAME"
echo "=========================================="
echo "Lambdas: $DEPLOY_LAMBDAS"
echo "UI:      $DEPLOY_UI"
echo "Force:   $FORCE_REBUILD"
[[ -n "$SINGLE_LAMBDA" ]] && echo "Lambda:  $SINGLE_LAMBDA"
echo ""

# -----------------------------------------------------------------------------
# Deploy Lambdas (targeted terragrunt apply)
# -----------------------------------------------------------------------------
if [[ "$DEPLOY_LAMBDAS" == "true" ]]; then
  echo "--- Building Lambdas ---"

  cd "$HOMETEST_SERVICE_DIR"
  LAMBDAS_SOURCE_DIR="$LAMBDAS_SOURCE_DIR" \
  LAMBDAS_CACHE_DIR="$LAMBDA_BUILD_CACHE" \
  NODE_ENV="production" \
  FORCE_LAMBDA_REBUILD="$FORCE_REBUILD" \
  mise exec -- "$SCRIPT_DIR/build-lambdas.sh"

  echo ""
  echo "--- Deploying Lambdas via targeted Terragrunt apply ---"
  cd "$TG_DIR"

  if [[ -n "$SINGLE_LAMBDA" ]]; then
    # Deploy a single lambda
    echo "Targeting: module.lambdas[\"$SINGLE_LAMBDA\"]"
    terragrunt apply \
      -target="module.lambdas[\"$SINGLE_LAMBDA\"].aws_lambda_function.this" \
      -auto-approve \
      -input=false
  else
    # Deploy all lambdas — build target flags dynamically
    TARGET_FLAGS=""
    for lambda_dir in "$LAMBDAS_BASE_PATH"/*/; do
      if [[ -d "$lambda_dir" ]]; then
        lambda_name=$(basename "$lambda_dir")
        # Only target lambdas that have a zip (i.e., were built)
        zip_file="$lambda_dir/$lambda_name.zip"
        if [[ -f "$zip_file" ]]; then
          TARGET_FLAGS="$TARGET_FLAGS -target=module.lambdas[\"$lambda_name\"].aws_lambda_function.this"
        fi
      fi
    done

    if [[ -z "$TARGET_FLAGS" ]]; then
      echo "No lambda zips found — nothing to deploy."
    else
      echo "Targeting all built lambdas..."
      # shellcheck disable=SC2086
      terragrunt apply \
        $TARGET_FLAGS \
        -auto-approve \
        -input=false
    fi
  fi

  echo "Lambdas deployed."
  echo ""
fi

# -----------------------------------------------------------------------------
# Deploy UI (build + S3 sync + CloudFront invalidation — no Terraform needed)
# -----------------------------------------------------------------------------
if [[ "$DEPLOY_UI" == "true" ]]; then
  echo "--- Building UI ---"

  # Read outputs from terraform state to get bucket, CloudFront ID, and domain URLs.
  # These are needed for NEXT_PUBLIC_* build-time variables and the upload target.
  cd "$TG_DIR"
  echo "Reading terraform outputs..."
  SPA_BUCKET=$(terragrunt output -raw spa_bucket_id 2>/dev/null || echo "")
  CLOUDFRONT_ID=$(terragrunt output -raw cloudfront_distribution_id 2>/dev/null || echo "")
  # environment_urls is a map — extract api and ui URLs via json
  ENV_URLS_JSON=$(terragrunt output -json environment_urls 2>/dev/null || echo "{}")
  BACKEND_URL=$(echo "$ENV_URLS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('api',''))" 2>/dev/null || echo "")
  SPA_ORIGIN=$(echo "$ENV_URLS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ui',''))" 2>/dev/null || echo "")

  if [[ -z "$SPA_BUCKET" ]]; then
    echo "Error: Could not read spa_bucket_id from terraform outputs."
    echo "Has the environment been fully deployed at least once?"
    exit 1
  fi

  echo "  Backend URL:    $BACKEND_URL"
  echo "  SPA Origin:     $SPA_ORIGIN"
  echo "  S3 Bucket:      $SPA_BUCKET"
  echo "  CloudFront ID:  $CLOUDFRONT_ID"

  # NHS Login authorize URL — defaults to sandpit; override with --nhs-login-url if needed.
  # When wiremock is enabled in env.hcl, pass the wiremock authorize URL instead.
  NHS_LOGIN_AUTHORIZE_URL="${NHS_LOGIN_AUTHORIZE_URL:-https://auth.sandpit.signin.nhs.uk/authorize}"
  USE_WIREMOCK_AUTH="${USE_WIREMOCK_AUTH:-false}"

  cd "$HOMETEST_SERVICE_DIR"
  SPA_SOURCE_DIR="$SPA_SOURCE_DIR" \
  SPA_CACHE_DIR="$SPA_BUILD_CACHE" \
  SPA_TYPE="nextjs" \
  NEXT_PUBLIC_BACKEND_URL="$BACKEND_URL" \
  NEXT_PUBLIC_NHS_LOGIN_AUTHORIZE_URL="$NHS_LOGIN_AUTHORIZE_URL" \
  NEXT_PUBLIC_USE_WIREMOCK_AUTH="$USE_WIREMOCK_AUTH" \
  FORCE_SPA_REBUILD="$FORCE_REBUILD" \
  mise exec -- "$SCRIPT_DIR/build-spa.sh"

  echo ""
  echo "--- Uploading UI to S3 ---"

  CF_FLAG=""
  if [[ -n "$CLOUDFRONT_ID" ]]; then
    CF_FLAG="--cloudfront-id $CLOUDFRONT_ID"
  fi

  cd "$HOMETEST_SERVICE_DIR"
  # shellcheck disable=SC2086
  mise exec -- "$SCRIPT_DIR/upload-spa.sh" "$SPA_DIST_DIR" "$SPA_BUCKET" \
    --spa-type nextjs \
    --region "$AWS_REGION" \
    --spa-source-dir "$SPA_SOURCE_DIR" \
    $CF_FLAG

  echo "UI deployed."
  echo ""
fi

echo "=========================================="
echo "Quick deploy complete!"
echo "=========================================="
