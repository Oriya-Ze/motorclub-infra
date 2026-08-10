variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "motorclub"
}

variable "environment" {
  type    = string
  default = "serverless"
}

variable "lambda_image_tag" {
  description = "Immutable Lambda container image tag, preferably a Git commit SHA"
  type        = string
}

variable "database_url" {
  description = "Neon PostgreSQL URL (postgresql+asyncpg://...?ssl=require)"
  type        = string
  sensitive   = true
}

variable "enable_custom_domains" {
  type    = bool
  default = false
}

variable "manage_route53_records" {
  type    = bool
  default = false
}

variable "route53_hosted_zone_id" {
  type    = string
  default = null
}

variable "create_route53_zone" {
  description = "Create a new Route 53 hosted zone for domain_name (use when the zone does not exist yet)"
  type        = bool
  default     = false
}

variable "domain_name" {
  type    = string
  default = "motorclub.co.il"
}

variable "frontend_custom_domains" {
  type    = list(string)
  default = ["motorclub.co.il", "www.motorclub.co.il"]
}

variable "media_custom_domain" {
  type    = string
  default = "media.motorclub.co.il"
}

variable "api_custom_domain" {
  type    = string
  default = "api.motorclub.co.il"
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "allow_broad_media_cors" {
  description = "Allow '*' CORS on the media bucket until a specific frontend origin is known"
  type        = bool
  default     = true
}

variable "lambda_memory_size" {
  type    = number
  default = 512
}

variable "lambda_timeout" {
  type    = number
  default = 30
}

variable "cognito_domain_prefix" {
  description = "Globally unique Cognito Hosted UI domain prefix for OAuth (defaults to project-environment in module)"
  type        = string
  default     = ""
}

variable "google_oauth_client_id" {
  description = "Google OAuth client ID for Cognito Google sign-in"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret for Cognito Google sign-in"
  type        = string
  default     = ""
  sensitive   = true
}

check "route53_hosted_zone_required" {
  assert {
    condition = !var.manage_route53_records || var.create_route53_zone || (var.route53_hosted_zone_id != null && var.route53_hosted_zone_id != "")
    error_message = "Set create_route53_zone=true or route53_hosted_zone_id when manage_route53_records is true."
  }
}
