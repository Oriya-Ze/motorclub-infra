output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}

output "client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "client_secret" {
  value     = aws_cognito_user_pool_client.api.client_secret
  sensitive = true
}
