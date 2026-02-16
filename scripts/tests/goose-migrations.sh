#!/bin/bash

# Test Goose database migrations against a local PostgreSQL container
#
# Usage:
#   ./scripts/tests/goose-migrations.sh
#
# Prerequisites:
#   - Docker installed and running
#   - mise installed (will install goose automatically)
#
# Environment variables (optional):
#   POSTGRES_IMAGE    - PostgreSQL Docker image (default: postgres:16)
#   POSTGRES_USER     - Database user (default: testuser)
#   POSTGRES_PASSWORD - Database password (default: testpassword)
#   POSTGRES_DB       - Database name (default: testdb)
#   POSTGRES_PORT     - Host port to map (default: 5432)
#   KEEP_CONTAINER    - Set to "true" to keep container after tests (default: false)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MIGRATIONS_DIR="${PROJECT_ROOT}/infrastructure/modules/lambda-goose-migrator/src/migrations"

POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16}"
POSTGRES_USER="${POSTGRES_USER:-testuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-testpassword}"
POSTGRES_DB="${POSTGRES_DB:-testdb}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
KEEP_CONTAINER="${KEEP_CONTAINER:-false}"

CONTAINER_NAME="goose-migrations-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Functions
# ==============================================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

cleanup() {
  if [[ "${KEEP_CONTAINER}" != "true" ]]; then
    log_info "Cleaning up container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
  else
    log_warn "Container ${CONTAINER_NAME} kept running (KEEP_CONTAINER=true)"
  fi
}

wait_for_postgres() {
  local max_attempts=30
  local attempt=1

  log_info "Waiting for PostgreSQL to be ready..."
  until docker exec "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; do
    if [[ ${attempt} -ge ${max_attempts} ]]; then
      log_error "PostgreSQL failed to become ready after ${max_attempts} attempts"
      return 1
    fi
    echo -n "."
    sleep 1
    ((attempt++))
  done
  echo ""
  log_info "PostgreSQL is ready!"
}

ensure_goose() {
  if command -v goose &>/dev/null; then
    log_info "Using goose: $(goose --version 2>&1 | head -1)"
    return 0
  fi

  if command -v mise &>/dev/null; then
    log_info "Installing goose via mise..."
    mise install "aqua:pressly/goose"
    eval "$(mise env)"
    if command -v goose &>/dev/null; then
      log_info "Goose installed: $(goose --version 2>&1 | head -1)"
      return 0
    fi
  fi

  log_error "goose not found. Please install it via 'mise install' or 'go install github.com/pressly/goose/v3/cmd/goose@latest'"
  return 1
}

run_goose() {
  local cmd="$1"
  shift
  GOOSE_DRIVER=postgres \
  GOOSE_DBSTRING="host=localhost port=${POSTGRES_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD} dbname=${POSTGRES_DB} sslmode=disable" \
  goose -dir "${MIGRATIONS_DIR}" "${cmd}" "$@"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  trap cleanup EXIT

  cd "${PROJECT_ROOT}"

  log_info "=== Goose Migration Tests ==="
  log_info "Migrations directory: ${MIGRATIONS_DIR}"

  # Check prerequisites
  if [[ ! -d "${MIGRATIONS_DIR}" ]]; then
    log_error "Migrations directory not found: ${MIGRATIONS_DIR}"
    exit 1
  fi

  ensure_goose

  # Start PostgreSQL container
  log_info "Starting PostgreSQL container (${POSTGRES_IMAGE})..."
  docker run -d \
    --name "${CONTAINER_NAME}" \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -p "${POSTGRES_PORT}:5432" \
    "${POSTGRES_IMAGE}"

  wait_for_postgres

  # Run migrations
  log_info "=== Migration Status (Initial) ==="
  run_goose status

  log_info "=== Running Migrations (Up) ==="
  run_goose up

  log_info "=== Migration Status (After Up) ==="
  run_goose status

  log_info "=== Verifying Tables ==="
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c '\dt'

  log_info "=== Goose Version Table ==="
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c 'SELECT * FROM goose_db_version;'

  log_info "=== Testing Rollback (Down) ==="
  run_goose down

  log_info "=== Migration Status (After Down) ==="
  run_goose status

  log_info "=== Testing Re-apply (Up again - idempotency) ==="
  run_goose up

  log_info "=== Final Migration Status ==="
  run_goose status

  log_info "=== All migration tests passed! ==="
}

main "$@"
