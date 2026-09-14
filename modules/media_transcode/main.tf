locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "media-transcode"
  })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "transcode" {
  statement {
    sid    = "MediaObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${var.media_bucket_arn}/users/*",
      "${var.media_bucket_arn}/processed/*",
    ]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "transcode" {
  name               = "${local.name_prefix}-media-transcode"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "transcode" {
  name   = "${local.name_prefix}-media-transcode"
  role   = aws_iam_role.transcode.id
  policy = data.aws_iam_policy_document.transcode.json
}

resource "aws_cloudwatch_log_group" "transcode" {
  name              = "/aws/lambda/${local.name_prefix}-media-transcode"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_lambda_function" "transcode" {
  function_name                  = "${local.name_prefix}-media-transcode"
  role                           = aws_iam_role.transcode.arn
  package_type                   = "Image"
  image_uri                      = var.image_uri
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  architectures                  = ["x86_64"]
  ephemeral_storage {
    size = 10240
  }

  environment {
    variables = {
      DATABASE_URL = var.database_url
    }
  }

  depends_on = [aws_cloudwatch_log_group.transcode]

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcode.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.media_bucket_arn
}

resource "aws_s3_bucket_notification" "media_video_upload" {
  bucket = var.media_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".mp4"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".mov"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".webm"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".png"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".webp"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
    filter_suffix       = ".gif"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
