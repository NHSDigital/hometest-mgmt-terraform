#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Upload SPA Script
# Uploads a built SPA to an S3 bucket with proper cache-control headers,
# then optionally invalidates the CloudFront distribution cache.
#
# Supports Next.js and Vite/standard SPAs with type-specific caching strategies:
#   Next.js:
#     - Static assets (_next/static): immutable, max-age=31536000
#     - HTML files: no-cache (always revalidate)
#     - _next/data: short cache (max-age=60)
#   Vite:
#     - Hashed assets: max-age=31536000
#     - index.html: no-cache (always revalidate)
#
# Usage:
#   ./upload-spa.sh <spa-dist-dir> <s3-bucket> [options]
#
# Arguments:
#   spa-dist-dir   Path to the built SPA output directory
#   s3-bucket      Target S3 bucket name (without s3:// prefix)
#
# Options:
#   --spa-type TYPE          "nextjs" (default) or "vite"
#   --region REGION          AWS region (default: eu-west-2)
#   --cloudfront-id ID       CloudFront distribution ID for cache invalidation
#   --spa-source-dir DIR     Fallback source dir to locate build output
#   --skip-invalidation      Skip CloudFront cache invalidation
#
# Environment variables:
#   SKIP_SPA_UPLOAD=true     Skip upload entirely
# -----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SPA_DIST_INPUT="${1:-}"
S3_BUCKET="${2:-}"
SPA_TYPE="nextjs"
AWS_REGION="eu-west-2"
CLOUDFRONT_ID=""
SPA_SOURCE_DIR=""
SKIP_INVALIDATION="false"
SKIP_UPLOAD="${SKIP_SPA_UPLOAD:-false}"

# Parse remaining arguments
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spa-type)
      SPA_TYPE="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --cloudfront-id)
      CLOUDFRONT_ID="$2"
      shift 2
      ;;
    --spa-source-dir)
      SPA_SOURCE_DIR="$2"
      shift 2
      ;;
    --skip-invalidation)
      SKIP_INVALIDATION="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SPA_DIST_INPUT" ]] || [[ -z "$S3_BUCKET" ]]; then
  echo "Usage: $0 <spa-dist-dir> <s3-bucket> [options]"
  echo ""
  echo "Arguments:"
  echo "  spa-dist-dir   Path to the built SPA output directory"
  echo "  s3-bucket      Target S3 bucket name"
  echo ""
  echo "Options:"
  echo "  --spa-type TYPE          'nextjs' (default) or 'vite'"
  echo "  --region REGION          AWS region (default: eu-west-2)"
  echo "  --cloudfront-id ID       CloudFront distribution ID for cache invalidation"
  echo "  --spa-source-dir DIR     Fallback source dir to locate build output"
  echo "  --skip-invalidation      Skip CloudFront cache invalidation"
  echo ""
  echo "Environment variables:"
  echo "  SKIP_SPA_UPLOAD=true     Skip upload entirely"
  exit 1
fi

if [[ "$SKIP_UPLOAD" == "true" ]]; then
  echo "SPA upload skipped (SKIP_SPA_UPLOAD=true)"
  exit 0
fi

# -----------------------------------------------------------------------------
# Resolve dist directory
# -----------------------------------------------------------------------------

resolve_dist_dir() {
  local dist_dir="$1"

  # Try the provided path first
  if [[ -d "$dist_dir" ]] && [[ -n "$(ls -A "$dist_dir" 2>/dev/null)" ]]; then
    echo "$dist_dir"
    return 0
  fi

  # Fallback: try common output dirs relative to source
  if [[ -n "$SPA_SOURCE_DIR" ]]; then
    if [[ "$SPA_TYPE" == "nextjs" ]]; then
      for fallback in "$SPA_SOURCE_DIR/build" "$SPA_SOURCE_DIR/out" "$SPA_SOURCE_DIR/.next/static"; do
        if [[ -d "$fallback" ]] && [[ -n "$(ls -A "$fallback" 2>/dev/null)" ]]; then
          echo "$fallback"
          return 0
        fi
      done
    else
      for fallback in "$SPA_SOURCE_DIR/dist" "$SPA_SOURCE_DIR/build"; do
        if [[ -d "$fallback" ]] && [[ -n "$(ls -A "$fallback" 2>/dev/null)" ]]; then
          echo "$fallback"
          return 0
        fi
      done
    fi
  fi

  echo ""
  return 1
}

# -----------------------------------------------------------------------------
# Upload functions
# -----------------------------------------------------------------------------

upload_nextjs() {
  local dist="$1"
  local bucket="$2"

  echo "Uploading Next.js SPA with type-specific caching..."

  # 1. Sync all files with long cache (hashed assets)
  #    Exclude HTML (needs no-cache) and _next/data (needs short cache)
  echo "  Syncing static assets (max-age=31536000)..."
  aws s3 sync "$dist" "s3://$bucket" \
    --delete \
    --cache-control "max-age=31536000" \
    --exclude "*.html" \
    --exclude "_next/data/*" \
    --region "$AWS_REGION"

  # 2. Upload HTML files with no-cache (always revalidate for fresh content)
  local html_count
  html_count=$(find "$dist" -name "*.html" -type f 2>/dev/null | wc -l | xargs)
  if [[ "$html_count" -gt 0 ]]; then
    echo "  Uploading $html_count HTML file(s) (no-cache)..."
    aws s3 cp "$dist" "s3://$bucket" \
      --recursive \
      --exclude "*" \
      --include "*.html" \
      --cache-control "no-cache, no-store, must-revalidate" \
      --region "$AWS_REGION"
  fi

  # 3. Upload _next/data with short cache (ISR/SSG data files)
  if [[ -d "$dist/_next/data" ]]; then
    echo "  Syncing _next/data (max-age=60)..."
    aws s3 sync "$dist/_next/data" "s3://$bucket/_next/data" \
      --cache-control "max-age=60" \
      --region "$AWS_REGION"
  fi
}

upload_vite() {
  local dist="$1"
  local bucket="$2"

  echo "Uploading Vite/standard SPA with type-specific caching..."

  # 1. Sync all files with long cache (hashed assets)
  #    Exclude index.html (entry point needs no-cache)
  echo "  Syncing hashed assets (max-age=31536000)..."
  aws s3 sync "$dist" "s3://$bucket" \
    --delete \
    --cache-control "max-age=31536000" \
    --exclude "index.html" \
    --region "$AWS_REGION"

  # 2. Upload index.html with no-cache
  if [[ -f "$dist/index.html" ]]; then
    echo "  Uploading index.html (no-cache)..."
    aws s3 cp "$dist/index.html" "s3://$bucket/index.html" \
      --cache-control "no-cache, no-store, must-revalidate" \
      --region "$AWS_REGION"
  fi
}

invalidate_cloudfront() {
  local cf_id="$1"

  if [[ "$SKIP_INVALIDATION" == "true" ]]; then
    echo "CloudFront invalidation skipped (--skip-invalidation)"
    return 0
  fi

  if [[ -z "$cf_id" ]]; then
    echo "No CloudFront distribution ID provided, skipping invalidation"
    return 0
  fi

  echo "Invalidating CloudFront cache for distribution $cf_id..."
  aws cloudfront create-invalidation \
    --distribution-id "$cf_id" \
    --paths "/*" \
    --output text \
    --region "$AWS_REGION"
  echo "CloudFront cache invalidation initiated!"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

echo "=========================================="
echo "SPA Upload Script"
echo "=========================================="

# Resolve the dist directory
SPA_DIST=$(resolve_dist_dir "$SPA_DIST_INPUT") || true

if [[ -z "$SPA_DIST" ]]; then
  echo "Error: No SPA build output found at $SPA_DIST_INPUT"
  if [[ -n "$SPA_SOURCE_DIR" ]]; then
    echo "  Also checked fallback paths under $SPA_SOURCE_DIR"
  fi
  echo "  Run build-spa.sh first to generate the build output"
  exit 1
fi

# Resolve to absolute path
SPA_DIST=$(cd "$SPA_DIST" && pwd)

file_count=$(find "$SPA_DIST" -type f | wc -l | xargs)
echo "SPA type:       $SPA_TYPE"
echo "Source:         $SPA_DIST ($file_count files)"
echo "Target:         s3://$S3_BUCKET"
echo "Region:         $AWS_REGION"
echo "CloudFront ID:  ${CLOUDFRONT_ID:-<none>}"
echo ""

# Capture start time
start_time=$(date +%s)

# Upload based on SPA type
case "$SPA_TYPE" in
  nextjs)
    upload_nextjs "$SPA_DIST" "$S3_BUCKET"
    ;;
  vite)
    upload_vite "$SPA_DIST" "$S3_BUCKET"
    ;;
  *)
    echo "Error: Unknown SPA type '$SPA_TYPE'. Use 'nextjs' or 'vite'."
    exit 1
    ;;
esac

echo ""
echo "SPA uploaded successfully!"

# Invalidate CloudFront
invalidate_cloudfront "$CLOUDFRONT_ID"

# Calculate duration
end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "=========================================="
echo "SPA upload complete! (${duration}s)"
echo "=========================================="
echo ""
