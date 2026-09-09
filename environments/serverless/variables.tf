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

variable "transcode_lambda_image_tag" {
  description = "Immutable media transcode Lambda container image tag"
  type        = string
}

variable "database_url" {
  description = "Neon PostgreSQL URL (postgresql+asyncpg://...?ssl=require)"
  type        = string
  sensitive   = true
}

variable "enable_resend_email" {
  description = "Send Cognito auth emails via Resend (Custom Email Sender Lambda) instead of SES"
  type        = bool
  default     = true
}

variable "resend_secret_name" {
  description = "Secrets Manager name for Resend API key"
  type        = string
  default     = "motorclub/prod/resend"
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

variable "turnstile_site_key" {
  description = "Cloudflare Turnstile site key for auth CAPTCHA (free tier). Leave empty to disable."
  type        = string
  default     = ""
}

variable "turnstile_secret_key" {
  description = "Cloudflare Turnstile secret key"
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
