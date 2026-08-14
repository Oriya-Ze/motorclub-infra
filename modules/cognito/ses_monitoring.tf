data "archive_file" "ses_events" {
  count = var.enable_ses_email ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda/ses_events.zip"
  source {
    content  = file("${path.module}/lambda/ses_events/handler.py")
    filename = "handler.py"
  }
}

resource "aws_sesv2_account_suppression_attributes" "main" {
  count = var.enable_ses_email ? 1 : 0

  suppressed_reasons = ["BOUNCE", "COMPLAINT"]
}

resource "aws_sesv2_configuration_set" "transactional" {
  count = var.enable_ses_email ? 1 : 0

  configuration_set_name = "${local.name_prefix}-transactional"
}

resource "aws_sesv2_email_identity" "main" {
  count = var.enable_ses_email ? 1 : 0

  email_identity         = var.email_domain
  configuration_set_name = aws_sesv2_configuration_set.transactional[0].configuration_set_name

  depends_on = [aws_ses_domain_identity.main]
}

resource "aws_sns_topic" "ses_events" {
  count = var.enable_ses_email ? 1 : 0

  name = "${local.name_prefix}-ses-events"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ses-events"
  })
}

data "aws_iam_policy_document" "ses_sns_publish" {
  count = var.enable_ses_email ? 1 : 0

  statement {
    sid     = "AllowSESPublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    resources = [aws_sns_topic.ses_events[0].arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "ses_events" {
  count = var.enable_ses_email ? 1 : 0

  arn    = aws_sns_topic.ses_events[0].arn
  policy = data.aws_iam_policy_document.ses_sns_publish[0].json
}

resource "aws_sesv2_configuration_set_event_destination" "sns" {
  count = var.enable_ses_email ? 1 : 0

  configuration_set_name = aws_sesv2_configuration_set.transactional[0].configuration_set_name
  event_destination_name = "sns-all-events"

  event_destination {
    enabled = true
    matching_event_types = [
      "SEND",
      "REJECT",
      "BOUNCE",
      "COMPLAINT",
      "DELIVERY",
    ]

    sns_destination {
      topic_arn = aws_sns_topic.ses_events[0].arn
    }
  }
}

resource "aws_iam_role" "ses_events_lambda" {
  count = var.enable_ses_email ? 1 : 0

  name = "${local.name_prefix}-ses-events-lambda"

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

resource "aws_iam_role_policy_attachment" "ses_events_lambda_basic" {
  count = var.enable_ses_email ? 1 : 0

  role       = aws_iam_role.ses_events_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "ses_events" {
  count = var.enable_ses_email ? 1 : 0

  function_name = "${local.name_prefix}-ses-events"
  role          = aws_iam_role.ses_events_lambda[0].arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.ses_events[0].output_path
  source_code_hash = data.archive_file.ses_events[0].output_base64sha256

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ses-events"
  })
}

resource "aws_sns_topic_subscription" "ses_events_lambda" {
  count = var.enable_ses_email ? 1 : 0

  topic_arn = aws_sns_topic.ses_events[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ses_events[0].arn
}

resource "aws_lambda_permission" "sns_invoke_ses_events" {
  count = var.enable_ses_email ? 1 : 0

  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ses_events[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ses_events[0].arn
}

resource "aws_cloudwatch_log_group" "ses_events" {
  count = var.enable_ses_email ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-ses-events"
  retention_in_days = 14

  tags = local.common_tags
}
