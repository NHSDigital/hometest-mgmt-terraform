resource "aws_iam_role" "lambda_liquibase_migrator" {
  name = "lambda-liquibase-migrator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_liquibase_migrator_policy" {
  name        = "lambda-liquibase-migrator-policy"
  description = "Allow Lambda to connect to RDS and fetch secrets."
  policy      = data.aws_iam_policy_document.lambda_liquibase_migrator_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_liquibase_migrator_attach" {
  role       = aws_iam_role.lambda_liquibase_migrator.name
  policy_arn = aws_iam_policy.lambda_liquibase_migrator_policy.arn
}

module "liquibase_migrator_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  function_name          = "liquibase-migrator"
  handler                = "com.example.LiquibaseMigrator::handleRequest"
  runtime                = "java25"
  create_role            = false
  lambda_role            = var.lambda_role_arn
  timeout                = 300
  memory_size            = 512
  publish                = true
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids

  environment_variables = {
    DB_USERNAME   = var.db_username
    DB_ADDRESS    = var.db_address
    DB_PORT       = var.db_port
    DB_NAME       = var.db_name
    DB_SECRET_ARN = var.db_secret_arn
  }

  build_command = "./gradlew buildZip"
  artifact_path = "build/distributions/*.zip"
  source_path   = [
    "src/LiquibaseMigrator.java",
    "src/db/changelog/db.changelog-master.xml",
    "build.gradle"
  ]
}
