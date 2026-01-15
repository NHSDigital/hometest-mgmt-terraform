tflint {
  required_version = ">= 0.50"
}


plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# https://github.com/terraform-linters/tflint-ruleset-aws/releases
plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  call_module_type = "local"
}
