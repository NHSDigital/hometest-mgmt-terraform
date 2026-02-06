#!/usr/bin/env bash
#===============================================================================
# Lambda Build and Deploy Script
# Builds, packages, and uploads Lambda functions to S3
# Only rebuilds lambdas when source code changes (uses hash-based caching)
#
# Usage:
#   ./scripts/build-lambdas.sh [options]
#
# Options:
#   -e, --environment    Environment name (dev, dev1, dev2, staging, prod)
#   -l, --lambda         Specific lambda to build (default: all)
#   -s, --source-dir     Source directory containing lambdas (default: examples/lambdas)
#   -b, --bucket         S3 bucket name for deployment artifacts
#   -r, --region         AWS region (default: eu-west-2)
#   -n, --no-upload      Build and package only, don't upload to S3
#   -c, --clean          Clean build artifacts before building
#   -f, --force          Force rebuild even if source hasn't changed
#   -h, --help           Show this help message
#
# Examples:
#   ./scripts/build-lambdas.sh -e dev1
#   ./scripts/build-lambdas.sh -e dev1 -l api1-handler
#   ./scripts/build-lambdas.sh -e dev1 --no-upload
#   ./scripts/build-lambdas.sh -e dev1 --force    # Force rebuild all
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="${ROOT_DIR}/examples/lambdas"
ENVIRONMENT=""
SPECIFIC_LAMBDA=""
S3_BUCKET=""
AWS_REGION="${AWS_REGION:-eu-west-2}"
NO_UPLOAD=false
CLEAN=false
FORCE_BUILD=false
PROJECT_NAME="nhs-hometest"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Show help
show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -l|--lambda)
                SPECIFIC_LAMBDA="$2"
                shift 2
                ;;
            -s|--source-dir)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -b|--bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -n|--no-upload)
                NO_UPLOAD=true
                shift
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -f|--force)
                FORCE_BUILD=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Validate requirements
validate_requirements() {
    log_info "Validating requirements..."
    
    if [[ -z "$ENVIRONMENT" ]]; then
        log_error "Environment is required. Use -e or --environment"
        exit 1
    fi

    if ! command -v node &> /dev/null; then
        log_error "Node.js is required but not installed"
        exit 1
    fi

    if ! command -v npm &> /dev/null; then
        log_error "npm is required but not installed"
        exit 1
    fi

    if [[ "$NO_UPLOAD" == false ]]; then
        if ! command -v aws &> /dev/null; then
            log_error "AWS CLI is required but not installed"
            exit 1
        fi

        # Get S3 bucket from Terraform state if not provided
        if [[ -z "$S3_BUCKET" ]]; then
            log_info "Discovering S3 bucket from AWS account..."
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
            if [[ -n "$ACCOUNT_ID" ]]; then
                S3_BUCKET="${PROJECT_NAME}-${ACCOUNT_ID}-deployment-artifacts"
                log_info "Using bucket: $S3_BUCKET"
            else
                log_error "Could not determine AWS account. Please specify --bucket"
                exit 1
            fi
        fi
    fi

    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    log_success "Requirements validated"
}

# Get list of lambdas to build
get_lambdas() {
    if [[ -n "$SPECIFIC_LAMBDA" ]]; then
        if [[ -d "${SOURCE_DIR}/${SPECIFIC_LAMBDA}" ]]; then
            echo "$SPECIFIC_LAMBDA"
        else
            log_error "Lambda not found: ${SOURCE_DIR}/${SPECIFIC_LAMBDA}"
            exit 1
        fi
    else
        # Find all lambda directories (those with package.json)
        for dir in "${SOURCE_DIR}"/*/; do
            if [[ -f "${dir}package.json" ]]; then
                basename "$dir"
            fi
        done
    fi
}

# Clean build artifacts
clean_lambda() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    
    log_info "Cleaning ${lambda_name}..."
    
    rm -rf "${lambda_dir}/dist" "${lambda_dir}/node_modules" "${lambda_dir}/*.zip" "${lambda_dir}/.source_hash" 2>/dev/null || true
}

# Calculate hash of source files (excluding build artifacts)
calculate_source_hash() {
    local lambda_dir=$1
    
    # Hash all source files: *.ts, *.js, package.json, tsconfig.json
    # Exclude node_modules, dist, zip files
    find "$lambda_dir" \
        -type f \
        \( -name "*.ts" -o -name "*.js" -o -name "package.json" -o -name "tsconfig.json" -o -name "package-lock.json" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/dist/*" \
        -print0 2>/dev/null | \
        sort -z | \
        xargs -0 cat 2>/dev/null | \
        openssl dgst -sha256 | \
        awk '{print $2}'
}

# Check if lambda needs rebuilding
needs_rebuild() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    local hash_file="${lambda_dir}/.source_hash"
    local zip_file="${lambda_dir}/${lambda_name}.zip"
    
    # Force rebuild if requested
    if [[ "$FORCE_BUILD" == true ]]; then
        return 0  # needs rebuild
    fi
    
    # Rebuild if zip doesn't exist
    if [[ ! -f "$zip_file" ]]; then
        return 0  # needs rebuild
    fi
    
    # Rebuild if no previous hash
    if [[ ! -f "$hash_file" ]]; then
        return 0  # needs rebuild
    fi
    
    # Compare current source hash with stored hash
    local current_hash=$(calculate_source_hash "$lambda_dir")
    local stored_hash=$(cat "$hash_file" 2>/dev/null)
    
    if [[ "$current_hash" != "$stored_hash" ]]; then
        return 0  # needs rebuild
    fi
    
    return 1  # no rebuild needed
}

# Save source hash after successful build
save_source_hash() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    local hash_file="${lambda_dir}/.source_hash"
    
    calculate_source_hash "$lambda_dir" > "$hash_file"
}

# Build a single lambda
build_lambda() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    
    log_info "Building ${lambda_name}..."
    
    cd "$lambda_dir"
    
    # Install dependencies
    log_info "  Installing dependencies..."
    npm ci --silent 2>/dev/null || npm install --silent
    
    # Build (if build script exists)
    if grep -q '"build"' package.json; then
        log_info "  Compiling TypeScript..."
        npm run build --silent
    fi
    
    cd - > /dev/null
    log_success "Built ${lambda_name}"
}

# Package a single lambda
package_lambda() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    local output_file="${lambda_dir}/${lambda_name}.zip"
    
    log_info "Packaging ${lambda_name}..."
    
    cd "$lambda_dir"
    
    # Determine what to package
    local package_dir="dist"
    if [[ ! -d "dist" ]]; then
        package_dir="."
    fi
    
    # Create zip file
    rm -f "${lambda_name}.zip"
    
    if [[ "$package_dir" == "dist" ]]; then
        # For TypeScript projects, only include dist and production dependencies
        cd dist
        zip -rq "../${lambda_name}.zip" . -x "*.map"
        cd ..
        
        # Add node_modules if there are runtime dependencies
        if [[ -d "node_modules" ]] && grep -q '"dependencies"' package.json; then
            # Install production dependencies only
            npm ci --omit=dev --silent 2>/dev/null || npm install --omit=dev --silent
            zip -rq "${lambda_name}.zip" node_modules -x "*.d.ts" -x "*.map"
        fi
    else
        # For JavaScript projects, include everything except dev stuff
        zip -rq "${lambda_name}.zip" . \
            -x "*.ts" -x "*.map" -x "tsconfig.json" \
            -x "node_modules/.bin/*" -x ".git/*" \
            -x "package-lock.json" -x ".npmrc"
    fi
    
    cd - > /dev/null
    
    # Show package info
    local size=$(du -h "$output_file" | cut -f1)
    log_success "Packaged ${lambda_name} (${size})"
}

# Upload lambda to S3
upload_lambda() {
    local lambda_name=$1
    local lambda_dir="${SOURCE_DIR}/${lambda_name}"
    local zip_file="${lambda_dir}/${lambda_name}.zip"
    local s3_key="lambdas/${ENVIRONMENT}/${lambda_name}.zip"
    
    log_info "Uploading ${lambda_name} to s3://${S3_BUCKET}/${s3_key}..."
    
    if [[ ! -f "$zip_file" ]]; then
        log_error "Package not found: $zip_file"
        return 1
    fi
    
    aws s3 cp "$zip_file" "s3://${S3_BUCKET}/${s3_key}" \
        --region "$AWS_REGION" \
        --only-show-errors
    
    # Calculate and display hash
    local hash=$(openssl dgst -sha256 -binary "$zip_file" | openssl enc -base64)
    
    log_success "Uploaded ${lambda_name}"
    echo -e "  ${BLUE}S3 URI:${NC} s3://${S3_BUCKET}/${s3_key}"
    echo -e "  ${BLUE}Hash:${NC}   ${hash}"
}

# Generate Terraform/Terragrunt variable output
generate_terraform_output() {
    local lambdas=("$@")
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Terraform Variable Output${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "# Add these source_hash values to your terragrunt.hcl lambdas map:"
    echo "# (or set use_placeholder_lambda = false and update source_hash)"
    echo ""
    echo "lambdas = {"
    
    for lambda_name in "${lambdas[@]}"; do
        local zip_file="${SOURCE_DIR}/${lambda_name}/${lambda_name}.zip"
        if [[ -f "$zip_file" ]]; then
            local hash=$(openssl dgst -sha256 -binary "$zip_file" | openssl enc -base64)
            echo "  \"${lambda_name}\" = {"
            echo "    # ... your other config ..."
            echo "    source_hash = \"${hash}\""
            echo "  }"
        fi
    done
    
    echo "}"
    echo ""
}

# Main execution
main() {
    parse_args "$@"
    validate_requirements
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Lambda Build & Deploy${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Environment: ${BLUE}${ENVIRONMENT}${NC}"
    echo -e "Source Dir:  ${BLUE}${SOURCE_DIR}${NC}"
    if [[ "$NO_UPLOAD" == false ]]; then
        echo -e "S3 Bucket:   ${BLUE}${S3_BUCKET}${NC}"
    fi
    echo ""
    
    # Get lambdas to build
    mapfile -t lambdas < <(get_lambdas)
    
    if [[ ${#lambdas[@]} -eq 0 ]]; then
        log_warn "No lambdas found to build"
        exit 0
    fi
    
    log_info "Found ${#lambdas[@]} lambda(s) to process"
    
    # Process each lambda
    for lambda_name in "${lambdas[@]}"; do
        echo ""
        echo -e "${YELLOW}--- Processing: ${lambda_name} ---${NC}"
        
        if [[ "$CLEAN" == true ]]; then
            clean_lambda "$lambda_name"
        fi
        
        # Check if rebuild is needed
        if needs_rebuild "$lambda_name"; then
            build_lambda "$lambda_name"
            package_lambda "$lambda_name"
            save_source_hash "$lambda_name"
            
            if [[ "$NO_UPLOAD" == false ]]; then
                upload_lambda "$lambda_name"
            fi
        else
            log_success "Skipping ${lambda_name} - no changes detected"
        fi
    done
    
    # Generate terraform output
    generate_terraform_output "${lambdas[@]}"
    
    echo ""
    log_success "All lambdas processed successfully!"
    
    if [[ "$NO_UPLOAD" == false ]]; then
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Update terragrunt.hcl with source_hash values above"
        echo "2. Set use_placeholder_lambda = false"
        echo "3. Run: cd infrastructure/environments/poc/${ENVIRONMENT}/hometest-app && terragrunt apply"
    fi
}

main "$@"
