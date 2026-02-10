# Set environment-level variables for dev2
locals {
  environment = "dev2"

  # Source paths - Override defaults to use examples directory
  # These are read by _envcommon/hometest-app.hcl via try()
  lambdas_source_dir = "${get_repo_root()}/examples/lambdas"
  lambdas_base_path  = "${get_repo_root()}/examples/lambdas"
  spa_source_dir     = "${get_repo_root()}/examples/spa"
  spa_dist_dir       = "${get_repo_root()}/examples/spa/dist"
  spa_type           = "vite"
}
