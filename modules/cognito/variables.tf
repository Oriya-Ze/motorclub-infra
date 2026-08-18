variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cognito_domain_prefix" {
  description = "Cognito Hosted UI domain prefix (must be globally unique). Defaults to project-environment."
  type        = string
  default     = ""
}

variable "google_client_id" {
  description = "Google OAuth 2.0 client ID for Cognito federated sign-in"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth 2.0 client secret for Cognito federated sign-in"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_callback_urls" {
  description = "App OAuth callback URLs registered on the Cognito app client"
  type        = list(string)
  default     = ["http://localhost:5173/auth/callback"]
}

variable "oauth_logout_urls" {
  description = "App logout redirect URLs for the Cognito app client"
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "extra_oauth_callback_urls" {
  description = "Additional OAuth callback URLs (e.g. CloudFront frontend URL)"
  type        = list(string)
  default     = []
}

variable "extra_oauth_logout_urls" {
  description = "Additional logout URLs"
  type        = list(string)
  default     = []
}

variable "enable_ses_email" {
  description = "Send Cognito verification and password emails via Amazon SES"
  type        = bool
  default     = false
}

variable "enable_resend_email" {
  description = "Send Cognito verification and password emails via Resend (Custom Email Sender Lambda)"
  type        = bool
  default     = false
}

variable "resend_secret_name" {
  description = "AWS Secrets Manager secret name/ARN containing the Resend API key"
  type        = string
  default     = "motorclub/prod/resend"
}

variable "from_name" {
  description = "Display name for outbound auth emails"
  type        = string
  default     = "MotorClub"
}

variable "app_name" {
  description = "Application name used in auth email templates"
  type        = string
  default     = "MotorClub"
}

variable "app_url" {
  description = "Application URL linked from auth emails"
  type        = string
  default     = "https://motorclub.co.il"
}

variable "email_domain" {
  description = "Domain verified in SES for outbound email"
  type        = string
  default     = ""
}

variable "from_email_address" {
  description = "From address for Cognito emails (must be on email_domain)"
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "Route 53 zone for SES verification and DKIM records"
  type        = string
  default     = null
}

variable "manage_route53_records" {
  description = "Create SES DNS records in Route 53 automatically"
  type        = bool
  default     = false
}
