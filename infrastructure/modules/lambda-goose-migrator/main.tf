resource "aws_iam_role" "lambda_goose_migrator" {
  name               = "lambda-goose-migrator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_goose_migrator_policy" {
  name        = "lambda-goose-migrator-policy"
  description = "Allow Lambda to connect to RDS and fetch secrets."
  policy      = data.aws_iam_policy_document.lambda_goose_migrator_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_goose_migrator_attach" {
  role       = aws_iam_role.lambda_goose_migrator.name
  policy_arn = aws_iam_policy.lambda_goose_migrator_policy.arn
}

module "goose_migrator_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  function_name          = "goose-migrator"
  handler                = "main"
  runtime                = "go1.x"
  create_role            = false
  lambda_role            = aws_iam_role.lambda_goose_migrator.arn
  timeout                = 300
  memory_size            = 128
  publish                = true
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids

  environment_variables = {
    DB_URL = var.db_url
  }

  architectures = ["amd64"]

  source_path = [
    "src/main.go"
  ]
  runtime_package_install_command = "go mod tidy"
}
