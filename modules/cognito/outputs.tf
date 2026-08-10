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

output "cognito_domain" {
  description = "Cognito Hosted UI domain prefix (empty when Google OAuth is disabled)"
  value       = length(aws_cognito_user_pool_domain.main) > 0 ? aws_cognito_user_pool_domain.main[0].domain : ""
}

output "google_oauth_enabled" {
  value = local.enable_google_oauth
}

output "ses_email_enabled" {
  value = var.enable_ses_email
}

output "ses_from_email_address" {
  value = var.enable_ses_email ? var.from_email_address : ""
}

output "cognito_hosted_ui_base_url" {
  description = "Base URL for Cognito Hosted UI / OAuth endpoints"
  value = local.enable_google_oauth ? "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${data.aws_region.current.id}.amazoncognito.com" : ""
}

data "aws_region" "current" {}
