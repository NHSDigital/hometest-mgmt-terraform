#!/bin/bash
# Deploy script for HomeTest Infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$ROOT_DIR/infrastructure"

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -e, --environment   Environment to deploy (dev1, dev2, all) [default: all]"
    echo "  -a, --action        Action to perform (plan, apply, destroy) [default: plan]"
    echo "  -b, --build         Build Lambda and SPA before deploying"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --environment dev1 --action apply"
    echo "  $0 -e all -a plan -b"
    echo "  $0 --build --action apply"
}

ENVIRONMENT="all"
ACTION="plan"
BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "======================================"
echo "HomeTest Infrastructure Deployment"
echo "======================================"
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"
echo "Build: $BUILD"
echo ""

# Build if requested
if [ "$BUILD" = true ]; then
    echo "Building applications..."
    "$SCRIPT_DIR/build.sh" "$ENVIRONMENT"
    echo ""
fi

# Deploy
cd "$INFRA_DIR/environments/poc"

if [ "$ENVIRONMENT" = "all" ]; then
    echo "Deploying all environments..."
    case $ACTION in
        plan)
            terragrunt run-all plan
            ;;
        apply)
            terragrunt run-all apply
            ;;
        destroy)
            terragrunt run-all destroy
            ;;
        *)
            echo "Unknown action: $ACTION"
            exit 1
            ;;
    esac
else
    echo "Deploying $ENVIRONMENT environment..."
    cd "$ENVIRONMENT/hometest-app"
    case $ACTION in
        plan)
            terragrunt plan
            ;;
        apply)
            terragrunt apply
            ;;
        destroy)
            terragrunt destroy
            ;;
        *)
            echo "Unknown action: $ACTION"
            exit 1
            ;;
    esac
fi

echo ""
echo "======================================"
echo "Deployment $ACTION completed!"
echo "======================================"
