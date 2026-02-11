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
  handler                = "bootstrap" # Do not change - for custom runtimes, this must be 'bootstrap'
  runtime                = "provided.al2023"
  create_role            = false
  lambda_role            = aws_iam_role.lambda_goose_migrator.arn
  timeout                = 300
  memory_size            = 128
  publish                = true
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids

  environment_variables = {
    DB_USERNAME   = var.db_username
    DB_ADDRESS    = var.db_address
    DB_PORT       = var.db_port
    DB_NAME       = var.db_name
    DB_SECRET_ARN = data.aws_rds_cluster.db.master_user_secret_arn
  }

  architectures = ["arm64"]

  recreate_missing_package = true

  source_path = [
    {
      path = "${path.module}/src"
      commands = [
        "go mod tidy",
        "GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o bootstrap main.go",
        ":zip",
      ]
      patterns = [
        "!.*",
        "bootstrap",
        "migrations/.*",
      ]
    }
  ]
}
