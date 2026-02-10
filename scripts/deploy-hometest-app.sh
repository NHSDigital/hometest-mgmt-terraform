#!/bin/bash
# -----------------------------------------------------------------------------
# HomeTest Service Deployment Script
# This script helps developers deploy Lambda functions and SPA to AWS
# -----------------------------------------------------------------------------

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${PROJECT_NAME:-nhs-hometest}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_PROFILE="${AWS_PROFILE:-${PROJECT_NAME}-${ENVIRONMENT}-deploy}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" &> /dev/null; then
        print_error "Unable to authenticate with AWS. Please configure profile: ${AWS_PROFILE}"
        print_info "Add the following to ~/.aws/config:"
        cat << EOF

[profile ${AWS_PROFILE}]
role_arn = arn:aws:iam::ACCOUNT_ID:role/${PROJECT_NAME}-${ENVIRONMENT}-developer-deploy
source_profile = default
mfa_serial = arn:aws:iam::YOUR_ACCOUNT_ID:mfa/YOUR_USERNAME

EOF
        exit 1
    fi

    print_info "Prerequisites check passed"
}

# Function to get AWS account ID
get_account_id() {
    aws sts get-caller-identity --profile "${AWS_PROFILE}" --query Account --output text
}

# Function to deploy Lambda
deploy_lambda() {
    local function_name="$1"
    local zip_path="$2"

    if [[ -z "$function_name" ]] || [[ -z "$zip_path" ]]; then
        print_error "Usage: deploy_lambda <function-name> <zip-path>"
        exit 1
    fi

    if [[ ! -f "$zip_path" ]]; then
        print_error "Lambda zip file not found: $zip_path"
        exit 1
    fi

    local account_id=$(get_account_id)
    local bucket_name="${PROJECT_NAME}-${ENVIRONMENT}-artifacts-${account_id}"
    local s3_key="lambdas/${function_name}.zip"
    local full_function_name="${PROJECT_NAME}-${ENVIRONMENT}-${function_name}"

    print_info "Deploying Lambda: ${function_name}"
    print_info "  Source: ${zip_path}"
    print_info "  S3 Bucket: ${bucket_name}"
    print_info "  S3 Key: ${s3_key}"

    # Upload to S3
    print_info "Uploading to S3..."
    aws s3 cp "${zip_path}" "s3://${bucket_name}/${s3_key}" \
        --profile "${AWS_PROFILE}"

    # Update Lambda function
    print_info "Updating Lambda function code..."
    aws lambda update-function-code \
        --function-name "${full_function_name}" \
        --s3-bucket "${bucket_name}" \
        --s3-key "${s3_key}" \
        --profile "${AWS_PROFILE}"

    print_info "Lambda deployed successfully: ${full_function_name}"
}

# Function to deploy all Lambdas
deploy_all_lambdas() {
    local lambdas_dist="${REPO_ROOT}/../hometest-service/lambdas/dist"

    if [[ ! -d "$lambdas_dist" ]]; then
        print_error "Lambda dist directory not found: $lambdas_dist"
        print_info "Please run 'npm run build' in the lambdas directory first"
        exit 1
    fi

    print_info "Deploying all Lambda functions..."

    for zip_file in "${lambdas_dist}"/*.zip; do
        if [[ -f "$zip_file" ]]; then
            local function_name=$(basename "$zip_file" .zip | sed 's/-lambda$//')
            deploy_lambda "$function_name" "$zip_file"
        fi
    done

    print_info "All Lambda functions deployed successfully"
}

# Function to deploy SPA
deploy_spa() {
    local build_dir="$1"

    if [[ -z "$build_dir" ]]; then
        build_dir="${REPO_ROOT}/../hometest-service/ui/out"
    fi

    if [[ ! -d "$build_dir" ]]; then
        print_error "SPA build directory not found: $build_dir"
        print_info "Please run 'npm run build' in the UI directory first"
        exit 1
    fi

    local account_id=$(get_account_id)
    local bucket_name="${PROJECT_NAME}-${ENVIRONMENT}-spa-${account_id}"

    print_info "Deploying SPA to S3..."
    print_info "  Source: ${build_dir}"
    print_info "  Bucket: ${bucket_name}"

    # Sync to S3
    aws s3 sync "${build_dir}" "s3://${bucket_name}" \
        --delete \
        --profile "${AWS_PROFILE}"

    print_info "SPA deployed to S3 successfully"
}

# Function to invalidate CloudFront cache
invalidate_cloudfront() {
    local distribution_id="$1"

    if [[ -z "$distribution_id" ]]; then
        print_info "Fetching CloudFront distribution ID..."
        # Try to get distribution ID from tags
        distribution_id=$(aws cloudfront list-distributions \
            --profile "${AWS_PROFILE}" \
            --query "DistributionList.Items[?contains(Comment, '${PROJECT_NAME}-${ENVIRONMENT}')].Id" \
            --output text | head -1)
    fi

    if [[ -z "$distribution_id" ]]; then
        print_warn "Could not find CloudFront distribution ID"
        print_info "Please provide distribution ID manually:"
        print_info "  $0 invalidate <distribution-id>"
        return 1
    fi

    print_info "Invalidating CloudFront cache..."
    print_info "  Distribution ID: ${distribution_id}"

    local invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "${distribution_id}" \
        --paths "/*" \
        --profile "${AWS_PROFILE}" \
        --query "Invalidation.Id" \
        --output text)

    print_info "Invalidation created: ${invalidation_id}"
    print_info "CloudFront cache invalidation in progress"
}

# Function to show Lambda logs
show_logs() {
    local function_name="$1"
    local since="${2:-5m}"

    if [[ -z "$function_name" ]]; then
        print_error "Usage: show_logs <function-name> [since]"
        exit 1
    fi

    local full_function_name="${PROJECT_NAME}-${ENVIRONMENT}-${function_name}"
    local log_group="/aws/lambda/${full_function_name}"

    print_info "Showing logs for: ${full_function_name}"
    print_info "  Since: ${since}"

    aws logs tail "${log_group}" \
        --since "${since}" \
        --follow \
        --profile "${AWS_PROFILE}"
}

# Function to show usage
show_usage() {
    cat << EOF
HomeTest Service Deployment Script

Usage: $0 <command> [options]

Commands:
    lambda <name> <zip>   Deploy a specific Lambda function
    all-lambdas           Deploy all Lambda functions from dist/
    spa [build-dir]       Deploy SPA to S3
    invalidate [id]       Invalidate CloudFront cache
    logs <name> [since]   Show Lambda logs (default: last 5 minutes)
    check                 Check prerequisites

Environment Variables:
    PROJECT_NAME          Project name (default: nhs-hometest)
    ENVIRONMENT           Environment name (default: dev)
    AWS_PROFILE           AWS CLI profile (default: \${PROJECT_NAME}-\${ENVIRONMENT}-deploy)

Examples:
    $0 lambda eligibility-test-info ./dist/eligibility-test-info-lambda.zip
    $0 all-lambdas
    $0 spa ./ui/out
    $0 invalidate E1234567890
    $0 logs eligibility-test-info 30m

EOF
}

# Main script
main() {
    case "$1" in
        lambda)
            check_prerequisites
            deploy_lambda "$2" "$3"
            ;;
        all-lambdas)
            check_prerequisites
            deploy_all_lambdas
            ;;
        spa)
            check_prerequisites
            deploy_spa "$2"
            ;;
        invalidate)
            check_prerequisites
            invalidate_cloudfront "$2"
            ;;
        logs)
            check_prerequisites
            show_logs "$2" "$3"
            ;;
        check)
            check_prerequisites
            print_info "All checks passed!"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
