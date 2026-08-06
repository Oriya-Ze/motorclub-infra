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
  value       = trimsuffix(aws_apigatewayv2_stage.default.invoke_url, "/")
}
