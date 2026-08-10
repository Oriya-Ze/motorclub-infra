data "archive_file" "sms_auth_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/sms_auth/index.py"
  output_path = "${path.module}/lambda/sms_auth.zip"
}

resource "aws_iam_role" "sms_auth_lambda" {
  name = "${local.name_prefix}-cognito-sms-auth"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "sms_auth_lambda_basic" {
  role       = aws_iam_role.sms_auth_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sms_auth_lambda_sns" {
  name = "${local.name_prefix}-cognito-sms-auth-sns"
  role = aws_iam_role.sms_auth_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "sms_auth" {
  filename         = data.archive_file.sms_auth_lambda.output_path
  source_code_hash = data.archive_file.sms_auth_lambda.output_base64sha256
  function_name    = "${local.name_prefix}-cognito-sms-auth"
  role             = aws_iam_role.sms_auth_lambda.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      SMS_SENDER_ID = "MotorClub"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cognito-sms-auth"
  })
}

resource "aws_lambda_permission" "sms_auth_cognito" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sms_auth.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

resource "aws_iam_role" "cognito_sms" {
  name = "${local.name_prefix}-cognito-sms"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cognito-idp.amazonaws.com" }
      Condition = {
        StringEquals = { "sts:ExternalId" = "${local.name_prefix}-cognito-sms" }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cognito_sms" {
  name = "${local.name_prefix}-cognito-sms-publish"
  role = aws_iam_role.cognito_sms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = "*"
    }]
  })
}
