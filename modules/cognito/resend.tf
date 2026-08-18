# Cognito Custom Email Sender → Resend (replaces SES when enable_resend_email = true)

data "aws_secretsmanager_secret" "resend" {
  count = var.enable_resend_email ? 1 : 0
  name  = var.resend_secret_name
}

data "aws_iam_policy_document" "resend_email_assume" {
  count = var.enable_resend_email ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "resend_email" {
  count = var.enable_resend_email ? 1 : 0

  name               = "${local.name_prefix}-cognito-resend-email"
  assume_role_policy = data.aws_iam_policy_document.resend_email_assume[0].json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cognito-resend-email"
  })
}

resource "aws_kms_key" "cognito_email" {
  count = var.enable_resend_email ? 1 : 0

  description             = "Encrypt Cognito verification codes for ${local.name_prefix} custom email sender"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCognitoEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
        Action = [
          "kms:CreateGrant",
          "kms:Encrypt",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "cognito-idp.${data.aws_region.current.name}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.resend_email[0].arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cognito-email"
  })
}

resource "aws_kms_alias" "cognito_email" {
  count = var.enable_resend_email ? 1 : 0

  name          = "alias/${local.name_prefix}-cognito-email"
  target_key_id = aws_kms_key.cognito_email[0].key_id
}

data "aws_iam_policy_document" "resend_email" {
  count = var.enable_resend_email ? 1 : 0

  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [data.aws_secretsmanager_secret.resend[0].arn]
  }

  statement {
    sid    = "KmsDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.cognito_email[0].arn]
  }
}

resource "aws_iam_role_policy" "resend_email" {
  count = var.enable_resend_email ? 1 : 0

  name   = "${local.name_prefix}-cognito-resend-email"
  role   = aws_iam_role.resend_email[0].id
  policy = data.aws_iam_policy_document.resend_email[0].json
}

resource "aws_iam_role_policy_attachment" "resend_email_logs" {
  count = var.enable_resend_email ? 1 : 0

  role       = aws_iam_role.resend_email[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "null_resource" "resend_email_package" {
  count = var.enable_resend_email ? 1 : 0

  triggers = {
    handler_hash = filemd5("${path.module}/lambda/resend_email/handler.py")
    req_hash     = filemd5("${path.module}/lambda/resend_email/requirements.txt")
    script_hash  = filemd5("${path.module}/scripts/build-resend-lambda.sh")
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/build-resend-lambda.sh"
    interpreter = ["bash", "-c"]
  }
}

resource "aws_lambda_function" "resend_email" {
  count = var.enable_resend_email ? 1 : 0

  depends_on = [null_resource.resend_email_package]

  function_name = "${local.name_prefix}-cognito-resend-email"
  role          = aws_iam_role.resend_email[0].arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 15
  memory_size   = 256

  filename         = "${path.module}/lambda/resend_email.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/resend_email.zip")

  environment {
    variables = {
      RESEND_SECRET_ARN = data.aws_secretsmanager_secret.resend[0].arn
      KMS_KEY_ARN       = aws_kms_key.cognito_email[0].arn
      FROM_EMAIL        = var.from_email_address
      FROM_NAME         = var.from_name
      APP_NAME          = var.app_name
      APP_URL           = var.app_url
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cognito-resend-email"
  })
}

resource "aws_lambda_permission" "cognito_resend_email" {
  count = var.enable_resend_email ? 1 : 0

  statement_id  = "AllowCognitoInvoke"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.resend_email[0].function_name
  principal       = "cognito-idp.amazonaws.com"
  source_arn      = aws_cognito_user_pool.main.arn
}

resource "aws_cloudwatch_log_group" "resend_email" {
  count = var.enable_resend_email ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.resend_email[0].function_name}"
  retention_in_days = 14

  tags = local.common_tags
}
