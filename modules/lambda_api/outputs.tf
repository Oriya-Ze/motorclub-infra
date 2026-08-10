output "api_invoke_url" {
  description = "Public HTTP API base URL (includes trailing stage path for default stage)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.http.id
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.api.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "api_url" {
  description = "API base URL for frontend configuration"
  value = var.enable_api_custom_domain && var.api_custom_domain != null ? "https://${var.api_custom_domain}" : trimsuffix(
    aws_apigatewayv2_stage.default.invoke_url,
    "/"
  )
}

output "api_domain_target_domain_name" {
  description = "API Gateway regional domain target for Route53 alias records"
  value       = try(aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].target_domain_name, null)
}

output "api_domain_hosted_zone_id" {
  description = "Route53 hosted zone ID for API Gateway regional domain alias records"
  value       = try(aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].hosted_zone_id, null)
}
