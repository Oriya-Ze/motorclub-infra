output "frontend_cloudfront_domain" {
  value = module.edge.frontend_cloudfront_domain
}

output "media_cloudfront_domain" {
  value = module.edge.media_cloudfront_domain
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "ecr_backend_repository_url" {
  value = module.compute.ecr_backend_repository_url
}

output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.compute.ecs_service_name
}

output "migration_task_definition_arn" {
  value = module.compute.migration_task_definition_arn
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "ecs_security_group_id" {
  value = module.network.ecs_security_group_id
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
  description = "CloudFront URL initially; custom domain after enable_custom_domains"
  value       = module.edge.frontend_url
}

output "media_url" {
  description = "CloudFront URL initially; custom domain after enable_custom_domains"
  value       = module.edge.media_url
}

output "api_url" {
  description = "HTTP ALB URL for initial smoke tests; HTTPS custom domain when enabled"
  value       = local.api_url
}

output "database_secret_arn" {
  value     = module.database.database_secret_arn
  sensitive = true
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

output "frontend_build_env" {
  description = "Suggested build-time environment variables for the motorclub frontend"
  value = {
    VITE_API_URL        = "${local.api_url}/api/v1"
    VITE_MEDIA_BASE_URL = module.edge.media_url
  }
}
