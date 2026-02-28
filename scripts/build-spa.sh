#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Build SPA Script
# Only rebuilds the SPA when source code or configuration changes are detected.
# Uses content hashing (including NEXT_PUBLIC_BACKEND_URL) to determine if a
# rebuild is necessary — changing the backend URL triggers a rebuild.
#
# Usage:
#   ./build-spa.sh <spa-directory> <cache-directory> <backend-url> [spa-type]
#
# Arguments:
#   spa-directory   Path to the SPA source directory (e.g., hometest-service/ui)
#   cache-directory Path to store build cache (e.g., .spa-build-cache)
#   backend-url     The NEXT_PUBLIC_BACKEND_URL to bake into the build
#   spa-type        "nextjs" (default) or "vite"
#
# Environment variables:
#   FORCE_SPA_REBUILD=true  Force rebuild even if no changes detected
# -----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SPA_DIR_INPUT="${1:-}"
CACHE_DIR_INPUT="${2:-.spa-build-cache}"
BACKEND_URL="${3:-}"
SPA_TYPE="${4:-nextjs}"
FORCE_REBUILD="${FORCE_SPA_REBUILD:-false}"

if [[ -z "$SPA_DIR_INPUT" ]]; then
  echo "Usage: $0 <spa-directory> <cache-directory> <backend-url> [spa-type]"
  echo "  spa-directory:   Path to the SPA source directory"
  echo "  cache-directory: Path to store build cache (default: .spa-build-cache)"
  echo "  backend-url:     NEXT_PUBLIC_BACKEND_URL to bake into the build"
  echo "  spa-type:        'nextjs' (default) or 'vite'"
  echo ""
  echo "Environment variables:"
  echo "  FORCE_SPA_REBUILD=true  Force rebuild even if no changes detected"
  exit 1
fi

# Resolve to absolute paths
if [[ ! -d "$SPA_DIR_INPUT" ]]; then
  echo "Error: SPA directory not found: $SPA_DIR_INPUT"
  exit 1
fi
SPA_DIR=$(cd "$SPA_DIR_INPUT" && pwd)

# Create and resolve cache directory
mkdir -p "$CACHE_DIR_INPUT"
CACHE_DIR=$(cd "$CACHE_DIR_INPUT" && pwd)

# Cache file locations
HASH_FILE="$CACHE_DIR/spa.hash"
BUILD_LOG="$CACHE_DIR/last-spa-build.log"

# Determine output directory based on SPA type
if [[ "$SPA_TYPE" == "nextjs" ]]; then
  # Next.js: check next.config.ts/js for distDir, fall back to "build" then "out"
  if [[ -d "$SPA_DIR/build" ]] || grep -qsE 'distDir.*build' "$SPA_DIR/next.config.ts" "$SPA_DIR/next.config.js" "$SPA_DIR/next.config.mjs" 2>/dev/null; then
    DIST_DIR="$SPA_DIR/build"
  else
    DIST_DIR="$SPA_DIR/out"
  fi
else
  DIST_DIR="$SPA_DIR/dist"
fi

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

calculate_source_hash() {
  # Calculate hash of all source files that affect the build:
  # - Source code (*.ts, *.tsx, *.js, *.jsx, *.css, *.scss, *.json in src/)
  # - Public assets (public/)
  # - Content files (content/ — e.g., MDX, Markdown)
  # - Config files (package.json, package-lock.json, next.config.*, tsconfig.json, etc.)
  # - The NEXT_PUBLIC_BACKEND_URL (changing the URL means a different build)

  local hash_cmd="sha256sum"
  if ! command -v sha256sum &> /dev/null; then
    hash_cmd="md5sum"
  fi

  local all_hashes=""

  # Hash all source code files
  if [[ -d "$SPA_DIR/src" ]]; then
    local src_hash
    src_hash=$(find "$SPA_DIR/src" -type f \( \
      -name "*.ts" -o \
      -name "*.tsx" -o \
      -name "*.js" -o \
      -name "*.jsx" -o \
      -name "*.mjs" -o \
      -name "*.cjs" -o \
      -name "*.css" -o \
      -name "*.scss" -o \
      -name "*.json" -o \
      -name "*.mdx" -o \
      -name "*.md" \
    \) 2>/dev/null | sort | xargs cat 2>/dev/null | $hash_cmd | cut -d' ' -f1)
    all_hashes+="src:${src_hash}|"
  fi

  # Hash public directory (images, fonts, etc.)
  if [[ -d "$SPA_DIR/public" ]]; then
    local public_hash
    public_hash=$(find "$SPA_DIR/public" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | $hash_cmd | cut -d' ' -f1)
    all_hashes+="public:${public_hash}|"
  fi

  # Hash content directory (MDX, Markdown, etc.)
  if [[ -d "$SPA_DIR/content" ]]; then
    local content_hash
    content_hash=$(find "$SPA_DIR/content" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | $hash_cmd | cut -d' ' -f1)
    all_hashes+="content:${content_hash}|"
  fi

  # Hash hooks directory (React hooks)
  if [[ -d "$SPA_DIR/hooks" ]]; then
    local hooks_hash
    hooks_hash=$(find "$SPA_DIR/hooks" -type f \( \
      -name "*.ts" -o \
      -name "*.tsx" -o \
      -name "*.js" -o \
      -name "*.jsx" \
    \) 2>/dev/null | sort | xargs cat 2>/dev/null | $hash_cmd | cut -d' ' -f1)
    all_hashes+="hooks:${hooks_hash}|"
  fi

  # Hash config files at root level
  for file in \
    "$SPA_DIR/package.json" \
    "$SPA_DIR/package-lock.json" \
    "$SPA_DIR/tsconfig.json" \
    "$SPA_DIR/next.config.ts" \
    "$SPA_DIR/next.config.js" \
    "$SPA_DIR/next.config.mjs" \
    "$SPA_DIR/postcss.config.mjs" \
    "$SPA_DIR/postcss.config.js" \
    "$SPA_DIR/tailwind.config.ts" \
    "$SPA_DIR/tailwind.config.js" \
    "$SPA_DIR/vite.config.ts" \
    "$SPA_DIR/vite.config.js" \
    "$SPA_DIR/eslint.config.mjs"; do
    if [[ -f "$file" ]]; then
      local file_hash
      file_hash=$($hash_cmd "$file" | cut -d' ' -f1)
      all_hashes+="$(basename "$file"):${file_hash}|"
    fi
  done

  # Include backend URL in the hash — changing the API target requires a rebuild
  # because Next.js bakes NEXT_PUBLIC_* vars into the static output at build time.
  all_hashes+="BACKEND_URL:${BACKEND_URL}|"

  # Combine all hashes into final hash
  local final_hash
  final_hash=$(echo "$all_hashes" | $hash_cmd | cut -d' ' -f1)

  echo "$final_hash"
}

# For debugging: show what files are being hashed
show_hash_inputs() {
  echo "Files included in hash calculation:"

  if [[ -d "$SPA_DIR/src" ]]; then
    find "$SPA_DIR/src" -type f \( \
      -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o \
      -name "*.css" -o -name "*.scss" -o -name "*.json" -o -name "*.mdx" -o -name "*.md" \
    \) 2>/dev/null | wc -l | xargs printf "  %s files in src/\n"
  fi

  if [[ -d "$SPA_DIR/public" ]]; then
    find "$SPA_DIR/public" -type f 2>/dev/null | wc -l | xargs printf "  %s files in public/\n"
  fi

  if [[ -d "$SPA_DIR/content" ]]; then
    find "$SPA_DIR/content" -type f 2>/dev/null | wc -l | xargs printf "  %s files in content/\n"
  fi

  if [[ -d "$SPA_DIR/hooks" ]]; then
    find "$SPA_DIR/hooks" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null | wc -l | xargs printf "  %s files in hooks/\n"
  fi

  echo "  Config files:"
  for file in package.json package-lock.json tsconfig.json \
    next.config.ts next.config.js next.config.mjs \
    postcss.config.mjs postcss.config.js \
    tailwind.config.ts tailwind.config.js \
    vite.config.ts vite.config.js; do
    if [[ -f "$SPA_DIR/$file" ]]; then
      echo "    $file"
    fi
  done

  echo "  Environment:"
  echo "    NEXT_PUBLIC_BACKEND_URL=$BACKEND_URL"
}

get_cached_hash() {
  if [[ -f "$HASH_FILE" ]]; then
    cat "$HASH_FILE"
  else
    echo ""
  fi
}

save_hash() {
  local hash="$1"
  echo "$hash" > "$HASH_FILE"
}

needs_rebuild() {
  if [[ "$FORCE_REBUILD" == "true" ]]; then
    echo "Force rebuild requested via FORCE_SPA_REBUILD=true"
    return 0
  fi

  local current_hash
  current_hash=$(calculate_source_hash)
  local cached_hash
  cached_hash=$(get_cached_hash)

  if [[ -z "$cached_hash" ]]; then
    echo "No cached hash found - initial build required"
    return 0
  fi

  if [[ "$current_hash" != "$cached_hash" ]]; then
    echo "Source changes detected (hash changed)"
    echo "  Previous: ${cached_hash:0:16}..."
    echo "  Current:  ${current_hash:0:16}..."
    return 0
  fi

  # Check if dist directory exists and has content
  if [[ ! -d "$DIST_DIR" ]] || [[ -z "$(ls -A "$DIST_DIR" 2>/dev/null)" ]]; then
    echo "Output directory missing or empty ($DIST_DIR) - rebuild required"
    return 0
  fi

  # For Next.js static export, check for index.html
  if [[ "$SPA_TYPE" == "nextjs" ]] && [[ ! -f "$DIST_DIR/index.html" ]]; then
    echo "index.html not found in $DIST_DIR - rebuild required"
    return 0
  fi

  return 1
}

install_dependencies() {
  echo "Installing dependencies..."
  cd "$SPA_DIR"

  if [[ -f "package-lock.json" ]]; then
    npm ci --silent 2>/dev/null || npm install --silent 2>/dev/null || npm install
  else
    npm install --silent 2>/dev/null || npm install
  fi
}

build_spa() {
  echo "Building $SPA_TYPE SPA..."
  cd "$SPA_DIR"

  # Set environment variables for the build
  export NEXT_PUBLIC_BACKEND_URL="$BACKEND_URL"
  echo "  NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL"

  # Run the build
  npm run build --silent 2>/dev/null || npm run build
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

echo "=========================================="
echo "SPA Build Script"
echo "=========================================="
echo "SPA directory:  $SPA_DIR"
echo "SPA type:       $SPA_TYPE"
echo "Output dir:     $DIST_DIR"
echo "Cache directory: $CACHE_DIR"
echo "Backend URL:    $BACKEND_URL"
echo ""

# Validate source directory
if [[ ! -f "$SPA_DIR/package.json" ]]; then
  echo "Error: No package.json found in $SPA_DIR"
  exit 1
fi

# Show what's being tracked for changes
show_hash_inputs
echo ""

# Check if rebuild is needed
if needs_rebuild; then
  echo ""
  echo "Starting SPA build..."
  echo ""

  # Capture start time
  start_time=$(date +%s)

  # Run build steps
  install_dependencies
  build_spa

  # Verify output exists
  if [[ ! -d "$DIST_DIR" ]] || [[ -z "$(ls -A "$DIST_DIR" 2>/dev/null)" ]]; then
    echo "Error: Build output not found at $DIST_DIR"
    echo "Check your next.config.ts distDir / output settings"
    exit 1
  fi

  # Calculate and save new hash
  new_hash=$(calculate_source_hash)
  save_hash "$new_hash"

  # Calculate duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  # Count output files
  file_count=$(find "$DIST_DIR" -type f | wc -l | xargs)

  echo ""
  echo "=========================================="
  echo "SPA build complete! (${duration}s)"
  echo "Output: $DIST_DIR ($file_count files)"
  echo "Hash: ${new_hash:0:16}..."
  echo "=========================================="

  # Log build info
  {
    echo "Build completed: $(date -Iseconds)"
    echo "Duration: ${duration}s"
    echo "Hash: $new_hash"
    echo "Backend URL: $BACKEND_URL"
    echo "Output: $DIST_DIR ($file_count files)"
  } > "$BUILD_LOG"
else
  echo ""
  echo "=========================================="
  echo "No changes detected - skipping SPA build"
  echo "=========================================="

  if [[ -f "$BUILD_LOG" ]]; then
    echo ""
    echo "Last build info:"
    cat "$BUILD_LOG"
  fi
fi

echo ""
