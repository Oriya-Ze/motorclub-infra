data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3_media" {
  statement {
    sid    = "MediaObjectAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "arn:aws:s3:::${var.media_bucket_name}/users/*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_cognito" {
  count = var.auth_provider == "cognito" ? 1 : 0

  statement {
    sid    = "CognitoUserPoolAuth"
    effect = "Allow"
    actions = [
      "cognito-idp:SignUp",
      "cognito-idp:ConfirmSignUp",
      "cognito-idp:ResendConfirmationCode",
      "cognito-idp:InitiateAuth",
      "cognito-idp:ForgotPassword",
      "cognito-idp:ConfirmForgotPassword",
      "cognito-idp:ChangePassword",
      "cognito-idp:AdminGetUser",
    ]
    resources = [var.cognito_user_pool_arn]
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "lambda-api"
  })

  lambda_env = merge(
    {
      ENVIRONMENT                       = var.environment
      LOG_LEVEL                         = "INFO"
      APP_VERSION                       = var.app_version
      SERVICE_NAME                      = "motorclub-api"
      AUTH_PROVIDER                     = var.auth_provider
      DATABASE_URL                      = var.database_url
      BACKEND_CORS_ORIGINS              = var.backend_cors_origins
      MEDIA_STORAGE_PROVIDER            = "s3"
      S3_MEDIA_BUCKET                   = var.media_bucket_name
      MEDIA_BASE_URL                    = var.media_base_url
      S3_PRESIGNED_URL_EXPIRY_SECONDS   = "300"
      MAX_IMAGE_UPLOAD_BYTES            = "10485760"
      MAX_VIDEO_UPLOAD_BYTES            = "10485760"
      UPLOAD_DIR                        = "/tmp/uploads"
      RATE_LIMIT_TABLE                  = aws_dynamodb_table.rate_limit.name
    },
    var.auth_provider == "cognito" ? {
      COGNITO_USER_POOL_ID  = var.cognito_user_pool_id
      COGNITO_CLIENT_ID     = var.cognito_client_id
      COGNITO_CLIENT_SECRET = var.cognito_client_secret
      COGNITO_DOMAIN        = var.cognito_domain != null ? var.cognito_domain : ""
    } : {
      JWT_SECRET         = var.jwt_secret
      JWT_ALGORITHM      = "HS256"
      JWT_EXPIRE_MINUTES = "1440"
    }
  )
}

resource "aws_dynamodb_table" "rate_limit" {
  name         = "${local.name_prefix}-rate-limit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rate-limit"
  })
}

data "aws_iam_policy_document" "lambda_rate_limit" {
  statement {
    sid    = "RateLimitTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.rate_limit.arn]
  }
}

resource "aws_iam_role_policy" "lambda_rate_limit" {
  name   = "${local.name_prefix}-api-lambda-rate-limit"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_rate_limit.json
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-api-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-lambda-role"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_media" {
  name   = "${local.name_prefix}-api-lambda-s3"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_s3_media.json
}

resource "aws_iam_role_policy" "lambda_cognito" {
  count = var.auth_provider == "cognito" ? 1 : 0

  name   = "${local.name_prefix}-api-lambda-cognito"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_cognito[0].json
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "/aws/lambda/${local.name_prefix}-api"
  })
}

resource "aws_lambda_function" "api" {
  function_name = "${local.name_prefix}-api"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = local.lambda_env
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy_attachment.lambda_basic,
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api"
  })
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["*"]
    allow_methods     = ["*"]
    allow_origins     = [for origin in split(",", var.backend_cors_origins) : trimspace(origin) if trimspace(origin) != ""]
    max_age           = 300
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-api"
  })
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-api-default"
  })
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_apigatewayv2_domain_name" "api" {
  count = var.enable_api_custom_domain ? 1 : 0

  domain_name = var.api_custom_domain

  domain_name_configuration {
    certificate_arn = var.api_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-domain"
  })
}

resource "aws_apigatewayv2_api_mapping" "api" {
  count = var.enable_api_custom_domain ? 1 : 0

  api_id      = aws_apigatewayv2_api.http.id
  domain_name = aws_apigatewayv2_domain_name.api[0].id
  stage       = aws_apigatewayv2_stage.default.name
}
