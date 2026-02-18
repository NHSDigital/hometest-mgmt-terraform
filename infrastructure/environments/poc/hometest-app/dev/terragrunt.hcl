# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev ENVIRONMENT
# Deployment with: cd poc/hometest-app/dev && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from _envcommon/hometest-app.hcl.
# Environment name ("dev") is derived automatically from this directory name — no env.hcl needed.
# Only add overrides here for what's specific to this environment.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hometest-app.hcl"
  expose         = true
  merge_strategy = "deep"
}

# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-SPECIFIC OVERRIDES
# Only define inputs that differ from _envcommon/hometest-app.hcl
# The lambdas map below is deep-merged with the common lambdas.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  lambdas = {
    # Hello World Lambda - simple health check (dev environment only)
    # CloudFront: /hello-world/* → API Gateway → Lambda
    "hello-world-lambda" = {
      description     = "Hello World Lambda - Health Check"
      api_path_prefix = "hello-world"
      handler         = "index.handler"
      timeout         = 30
      memory_size     = 256
      environment = {
        NODE_OPTIONS = "--enable-source-maps"
        ENVIRONMENT  = include.envcommon.locals.environment
      }
    }
  }
}
