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

output "frontend_build_env" {
  description = "Suggested build-time environment variables for the motorclub frontend"
  value = {
    VITE_API_URL        = "${module.lambda_api.api_url}/api/v1"
    VITE_MEDIA_BASE_URL = module.edge.media_url
  }
}

output "cloudfront_certificate_validation_records" {
  description = "Manual DNS records for ACM when manage_route53_records=false"
  value       = module.edge.cloudfront_certificate_validation_options
}
