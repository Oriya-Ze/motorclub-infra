output "frontend_cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "media_cloudfront_domain" {
  value = aws_cloudfront_distribution.media.domain_name
}

output "frontend_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "media_distribution_id" {
  value = aws_cloudfront_distribution.media.id
}

output "frontend_url" {
  value = local.frontend_url
}

output "media_url" {
  value = local.media_url
}

output "cloudfront_certificate_arn" {
  value = try(aws_acm_certificate.cloudfront[0].arn, null)
}

output "cloudfront_certificate_validation_options" {
  description = "Create these DNS records manually when enable_custom_domains=true and manage_route53_records=false"
  value = var.enable_custom_domains ? [
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : {
      domain_name = dvo.domain_name
      name        = dvo.resource_record_name
      type        = dvo.resource_record_type
      value       = dvo.resource_record_value
    }
  ] : []
}
