output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

output "frontend_cloudfront_domain" {
  value = module.edge.frontend_cloudfront_domain
}

output "media_cloudfront_domain" {
  value = module.edge.media_cloudfront_domain
}

output "frontend_bucket_name" {
  value = module.storage.frontend_bucket_name
}

output "frontend_distribution_id" {
  value = module.edge.frontend_distribution_id
}

output "media_bucket_name" {
  value = module.storage.media_bucket_name
}

output "media_distribution_id" {
  value = module.edge.media_distribution_id
}

output "frontend_url" {
  value = module.edge.frontend_url
}

output "media_url" {
  value = module.edge.media_url
}

output "api_url" {
  description = "Public HTTP API (API Gateway) base URL"
  value       = module.lambda_api.api_url
}

output "api_invoke_url" {
  value = module.lambda_api.api_invoke_url
}

output "lambda_function_name" {
  value = module.lambda_api.lambda_function_name
}

output "ecr_api_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "cognito_hosted_ui_base_url" {
  value = nonsensitive(module.cognito.cognito_hosted_ui_base_url)
}

output "google_oauth_enabled" {
  value     = nonsensitive(module.cognito.google_oauth_enabled)
  sensitive = false
}

output "frontend_build_env" {
  description = "Suggested build-time environment variables for the motorclub frontend"
  value = {
    VITE_API_URL        = "${module.lambda_api.api_url}/api/v1"
    VITE_MEDIA_BASE_URL = module.edge.media_url
    VITE_TURNSTILE_SITE_KEY = var.turnstile_site_key != "" ? var.turnstile_site_key : null
  }
}

output "route53_hosted_zone_id" {
  description = "Route 53 hosted zone ID used for DNS records"
  value       = local.route53_zone_id
}

output "route53_name_servers" {
  description = "Update your domain registrar to use these nameservers when create_route53_zone=true"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : []
}

output "cloudfront_certificate_validation_records" {
  description = "Manual DNS records for ACM when manage_route53_records=false"
  value       = module.edge.cloudfront_certificate_validation_options
}

output "api_certificate_validation_records" {
  description = "Manual DNS records for regional API ACM when manage_route53_records=false"
  value = var.enable_custom_domains ? [
    for dvo in aws_acm_certificate.api[0].domain_validation_options : {
      domain_name = dvo.domain_name
      name        = dvo.resource_record_name
      type        = dvo.resource_record_type
      value       = dvo.resource_record_value
    }
  ] : []
}
