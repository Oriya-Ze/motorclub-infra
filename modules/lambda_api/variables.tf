variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image_uri" {
  description = "Full ECR image URI including tag for the API Lambda container"
  type        = string
}

variable "database_url" {
  description = "Neon PostgreSQL URL (postgresql+asyncpg://...)"
  type        = string
  sensitive   = true
}

variable "auth_provider" {
  description = "Authentication provider: cognito or local"
  type        = string
  default     = "cognito"

  validation {
    condition     = contains(["cognito", "local"], var.auth_provider)
    error_message = "auth_provider must be cognito or local."
  }
}

variable "jwt_secret" {
  description = "JWT signing secret when AUTH_PROVIDER=local"
  type        = string
  sensitive   = true
  default     = null
}

variable "cognito_user_pool_id" {
  type    = string
  default = null
}

variable "cognito_user_pool_arn" {
  type    = string
  default = null
}

variable "cognito_client_id" {
  type    = string
  default = null
}

variable "cognito_client_secret" {
  type      = string
  sensitive = true
  default   = null
}

variable "backend_cors_origins" {
  type = string
}

variable "media_bucket_name" {
  type = string
}

variable "media_base_url" {
  type = string
}

variable "memory_size" {
  type    = number
  default = 512
}

variable "timeout" {
  type    = number
  default = 30
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "app_version" {
  type    = string
  default = "serverless"
}

variable "tags" {
  type    = map(string)
  default = {}
}
