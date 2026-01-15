#!/bin/bash

set -e

# Configuration
DYNAMODB_TABLE="nhs-hometest-poc-dynamodb-tfstate-lock"
S3_BUCKET="nhs-hometest-poc-s3-tfstate"
AWS_REGION="${AWS_REGION:-eu-west-2}"

echo "=== Terraform State Resources Cleanup Script ==="
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "S3 Bucket: ${S3_BUCKET}"
echo "Region: ${AWS_REGION}"
echo ""

# Step 1: Disable DynamoDB deletion protection
echo "Step 1: Disabling DynamoDB deletion protection..."
aws dynamodb update-table \
    --table-name "${DYNAMODB_TABLE}" \
    --no-deletion-protection-enabled \
    --region "${AWS_REGION}" \
    2>/dev/null && echo "✓ Deletion protection disabled" || echo "⚠ Table may not exist or already unprotected"

# Step 2: Empty S3 bucket (delete all object versions and delete markers)
echo ""
echo "Step 2: Emptying S3 bucket (including all versions)..."

# Check if bucket exists
if aws s3api head-bucket --bucket "${S3_BUCKET}" 2>/dev/null; then
    # Delete all object versions
    echo "Deleting all object versions..."
    aws s3api list-object-versions \
        --bucket "${S3_BUCKET}" \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' \
        --output json 2>/dev/null | \
    jq -c '.[] | select(. != null)' | \
    while read -r obj; do
        key=$(echo "$obj" | jq -r '.Key')
        version_id=$(echo "$obj" | jq -r '.VersionId')
        echo "  Deleting: ${key} (version: ${version_id})"
        aws s3api delete-object \
            --bucket "${S3_BUCKET}" \
            --key "${key}" \
            --version-id "${version_id}" \
            --region "${AWS_REGION}"
    done

    # Delete all delete markers
    echo "Deleting all delete markers..."
    aws s3api list-object-versions \
        --bucket "${S3_BUCKET}" \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
        --output json 2>/dev/null | \
    jq -c '.[] | select(. != null)' | \
    while read -r obj; do
        key=$(echo "$obj" | jq -r '.Key')
        version_id=$(echo "$obj" | jq -r '.VersionId')
        echo "  Deleting marker: ${key} (version: ${version_id})"
        aws s3api delete-object \
            --bucket "${S3_BUCKET}" \
            --key "${key}" \
            --version-id "${version_id}" \
            --region "${AWS_REGION}"
    done

    echo "✓ S3 bucket emptied"

    # Step 3: Delete the S3 bucket
    echo ""
    echo "Step 3: Deleting S3 bucket..."
    aws s3api delete-bucket \
        --bucket "${S3_BUCKET}" \
        --region "${AWS_REGION}" \
        && echo "✓ S3 bucket deleted" || echo "⚠ Failed to delete bucket"
else
    echo "⚠ Bucket does not exist or not accessible"
fi

echo ""
echo "=== Cleanup complete ==="
echo "You can now run 'terraform destroy' or 'terragrunt destroy' again."
