# This file is for you! Edit it to implement your own hooks (make targets) into
# the project as automated steps to be executed on locally and in the CD pipeline.

include scripts/init.mk

# ==============================================================================
# Configuration Variables
# ==============================================================================

# Default environment (can be overridden: make deploy ENV=staging)
ENV ?= dev
ACCOUNT ?= poc
INFRA_DIR := infrastructure/environments/$(ACCOUNT)
ARTIFACTS_DIR := artifacts
LAMBDA_DIR := lambdas

# AWS Configuration
AWS_REGION ?= eu-west-2
AWS_PROFILE ?= Admin-PoC

# ==============================================================================
# Infrastructure Deployment Targets
# ==============================================================================

.PHONY: tf-init tf-plan tf-apply tf-destroy tf-output

# Export AWS_PROFILE for Terraform/Terragrunt
export AWS_PROFILE

tf-init: ## Initialize Terragrunt for all modules in an environment @Infrastructure
	@echo "🔧 Initializing Terragrunt for $(ENV) environment..."
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all init --no-color

tf-plan: ## Plan Terragrunt changes for an environment @Infrastructure
	@echo "📋 Planning Terragrunt changes for $(ENV) environment..."
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all -- plan -no-color

tf-apply: ## Apply Terragrunt changes for an environment @Infrastructure
	@echo "🚀 Applying Terragrunt changes for $(ENV) environment..."
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all -- apply -auto-approve -no-color

tf-destroy: ## Destroy Terragrunt resources for an environment (CAUTION!) @Infrastructure
	@echo "⚠️  WARNING: This will destroy all resources in $(ENV) environment!"
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all -- destroy -auto-approve -no-color

tf-output: ## Show Terragrunt outputs for an environment @Infrastructure
	@echo "📊 Showing outputs for $(ENV) environment..."
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all -- output -no-color

# ==============================================================================
# Module-specific Deployment Targets
# ==============================================================================

.PHONY: deploy-application deploy-api-gateway deploy-waf deploy-dns deploy-iam

deploy-application: ## Deploy only the application (Lambda) module @Infrastructure
	@echo "🔧 Deploying application module for $(ENV)..."
	cd $(INFRA_DIR)/$(ENV)/application && terragrunt run -- apply -auto-approve

deploy-api-gateway: ## Deploy only the API Gateway module @Infrastructure
	@echo "🔧 Deploying API Gateway module for $(ENV)..."
	cd $(INFRA_DIR)/$(ENV)/api-gateway && terragrunt run -- apply -auto-approve

deploy-waf: ## Deploy only the WAF module @Infrastructure
	@echo "🔧 Deploying WAF module for $(ENV)..."
	cd $(INFRA_DIR)/$(ENV)/waf && terragrunt run -- apply -auto-approve

deploy-dns: ## Deploy only the DNS/Certificate module @Infrastructure
	@echo "🔧 Deploying DNS/Certificate module for $(ENV)..."
	cd $(INFRA_DIR)/$(ENV)/dns-certificate && terragrunt run -- apply -auto-approve

deploy-iam: ## Deploy only the IAM Developer Role module @Infrastructure
	@echo "🔧 Deploying IAM Developer Role module for $(ENV)..."
	cd $(INFRA_DIR)/$(ENV)/iam-developer-role && terragrunt run -- apply -auto-approve

# ==============================================================================
# Lambda Artifact Management
# ==============================================================================

.PHONY: build-lambda package-lambda upload-lambda

build-lambda: ## Build Lambda function artifacts @Build
	@echo "🔨 Building Lambda artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)
	@if [ -d "$(LAMBDA_DIR)" ] && [ "$$(ls -A $(LAMBDA_DIR) 2>/dev/null)" ]; then \
		for lambda_dir in $(LAMBDA_DIR)/*; do \
			if [ -d "$$lambda_dir" ]; then \
				lambda_name=$$(basename $$lambda_dir); \
				echo "  Building $$lambda_name..."; \
				cd $$lambda_dir && npm ci --production 2>/dev/null || pip install -r requirements.txt -t . 2>/dev/null || true; \
				cd - > /dev/null; \
			fi; \
		done; \
	else \
		echo "  No Lambda functions found in $(LAMBDA_DIR)/"; \
		echo "  Create Lambda functions in $(LAMBDA_DIR)/<function-name>/"; \
	fi

package-lambda: build-lambda ## Package Lambda functions into zip artifacts @Build
	@echo "📦 Packaging Lambda artifacts..."
	@mkdir -p $(ARTIFACTS_DIR)
	@if [ -d "$(LAMBDA_DIR)" ] && [ "$$(ls -A $(LAMBDA_DIR) 2>/dev/null)" ]; then \
		for lambda_dir in $(LAMBDA_DIR)/*; do \
			if [ -d "$$lambda_dir" ]; then \
				lambda_name=$$(basename $$lambda_dir); \
				echo "  Packaging $$lambda_name..."; \
				cd $$lambda_dir && zip -r ../../$(ARTIFACTS_DIR)/$$lambda_name.zip . -x "*.git*" -x "*__pycache__*" -x "*.pytest*"; \
				cd - > /dev/null; \
			fi; \
		done; \
	else \
		echo "  No Lambda functions to package"; \
	fi

upload-lambda: package-lambda ## Upload Lambda artifacts to S3 @Build
	@echo "⬆️  Uploading Lambda artifacts to S3..."
	@BUCKET="nhs-hometest-$(ACCOUNT)-$(ENV)-lambda-artifacts"; \
	for artifact in $(ARTIFACTS_DIR)/*.zip; do \
		if [ -f "$$artifact" ]; then \
			filename=$$(basename $$artifact); \
			echo "  Uploading $$filename to s3://$$BUCKET/"; \
			aws s3 cp $$artifact s3://$$BUCKET/$$filename --profile $(AWS_PROFILE); \
		fi; \
	done

# ==============================================================================
# Environment Management
# ==============================================================================

.PHONY: new-env list-envs validate-env

new-env: ## Create a new environment (usage: make new-env NEW_ENV=feature-xyz) @Environment
ifndef NEW_ENV
	$(error NEW_ENV is required. Usage: make new-env NEW_ENV=feature-xyz)
endif
	@echo "🆕 Creating new environment: $(NEW_ENV)..."
	@mkdir -p $(INFRA_DIR)/$(NEW_ENV)
	@echo "# Set common variables for the environment." > $(INFRA_DIR)/$(NEW_ENV)/env.hcl
	@echo "locals {" >> $(INFRA_DIR)/$(NEW_ENV)/env.hcl
	@echo "  environment = \"$(NEW_ENV)\"" >> $(INFRA_DIR)/$(NEW_ENV)/env.hcl
	@echo "}" >> $(INFRA_DIR)/$(NEW_ENV)/env.hcl
	@# Copy module directories from dev as template
	@for module in application api-gateway waf dns-certificate iam-developer-role; do \
		if [ -d "$(INFRA_DIR)/dev/$$module" ]; then \
			mkdir -p $(INFRA_DIR)/$(NEW_ENV)/$$module; \
			cp $(INFRA_DIR)/dev/$$module/terragrunt.hcl $(INFRA_DIR)/$(NEW_ENV)/$$module/; \
		fi; \
	done
	@echo "✅ Environment $(NEW_ENV) created!"
	@echo "   Edit $(INFRA_DIR)/$(NEW_ENV)/ to customize."
	@echo "   Deploy with: make tf-apply ENV=$(NEW_ENV)"

list-envs: ## List all available environments @Environment
	@echo "📋 Available environments in $(ACCOUNT) account:"
	@ls -1 $(INFRA_DIR)/ | grep -v -E '^(account\.hcl|core)$$' | sed 's/^/   - /'

validate-env: ## Validate Terragrunt configuration for an environment @Environment
	@echo "✅ Validating $(ENV) environment configuration..."
	cd $(INFRA_DIR)/$(ENV) && terragrunt run --all validate

# ==============================================================================
# Development Utilities
# ==============================================================================

.PHONY: logs invoke-lambda test-api

logs: ## Tail CloudWatch logs for Lambda function @Development
	@echo "📜 Tailing logs for $(ENV) environment..."
	@FUNCTION="nhs-hometest-$(ACCOUNT)-$(ENV)-api"; \
	aws logs tail /aws/lambda/$$FUNCTION --follow --profile $(AWS_PROFILE)

invoke-lambda: ## Invoke Lambda function for testing @Development
	@echo "🔄 Invoking Lambda function in $(ENV)..."
	@FUNCTION="nhs-hometest-$(ACCOUNT)-$(ENV)-api"; \
	aws lambda invoke --function-name $$FUNCTION \
		--payload '{"httpMethod": "GET", "path": "/health"}' \
		--profile $(AWS_PROFILE) \
		/tmp/lambda-response.json && cat /tmp/lambda-response.json

test-api: ## Test API endpoint @Development
	@echo "🔬 Testing API endpoint for $(ENV)..."
	@ENDPOINT="https://$(ENV).hometest.service.nhs.uk/v1/health"; \
	curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" $$ENDPOINT || echo "Endpoint not yet available"

# ==============================================================================
# Legacy Targets (kept for compatibility)
# ==============================================================================

dependencies: ## Install dependencies needed to build and test the project @Pipeline
	@echo "📦 Installing dependencies..."
	@command -v terraform >/dev/null 2>&1 || echo "Please install terraform >= 1.14"
	@command -v terragrunt >/dev/null 2>&1 || echo "Please install terragrunt >= 0.97"
	@command -v aws >/dev/null 2>&1 || echo "Please install AWS CLI"

build: package-lambda ## Build the project artefact @Pipeline

publish: upload-lambda ## Publish the project artefact @Pipeline

deploy: tf-apply ## Deploy the project artefact to the target environment @Pipeline

tf-clean: ## Clean-up Terraform/Terragrunt caches @Operations
	@echo "🧹 Cleaning up..."
	rm -rf $(ARTIFACTS_DIR)/*.zip
	find $(INFRA_DIR) -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
	find $(INFRA_DIR) -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true

config:: ## Configure development environment (main) @Configuration
	@echo "⚙️  Configuring development environment..."
	make dependencies

# ==============================================================================
# Help (extends default help from scripts/init.mk)
# ==============================================================================

.PHONY: help-infra
help-infra: ## Show infrastructure-specific help @Help
	@echo "HomeTest Management Terraform - Available Commands"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|staging|prod] [ACCOUNT=poc]"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make tf-plan ENV=dev           # Plan dev environment"
	@echo "  make tf-apply ENV=dev          # Apply dev environment"
	@echo "  make new-env NEW_ENV=feature-1 # Create new feature environment"
	@echo "  make logs ENV=dev              # Tail Lambda logs"

# ==============================================================================

${VERBOSE}.SILENT: \
	build \
	clean \
	config \
	dependencies \
	deploy \
	help
