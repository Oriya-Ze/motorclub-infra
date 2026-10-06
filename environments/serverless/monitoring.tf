# Email alarms for production. Set alarm_email in terraform.tfvars, apply, then click the
# confirmation link AWS sends to that address. Until then the alarms fire but notify no one.

variable "alarm_email" {
  description = "Address that receives production alarms. Empty creates the alarms without a subscriber."
  type        = string
  default     = ""
}

locals {
  alarm_tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "monitoring"
  }
}

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
  tags = local.alarm_tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-errors"
  alarm_description   = "The API Lambda raised unhandled errors. Check its CloudWatch logs."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = module.lambda_api.lambda_function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "api_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-api-throttles"
  alarm_description   = "Requests to the API Lambda were throttled."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = module.lambda_api.lambda_function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx"
  alarm_description   = "API Gateway returned server errors to members."
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = module.lambda_api.api_id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "transcode_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-media-transcode-errors"
  alarm_description   = "The media Lambda failed to process an upload."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = module.media_transcode.lambda_function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.alarm_tags
}
