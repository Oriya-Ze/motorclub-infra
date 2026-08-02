variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_app_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "application_secret_arn" {
  type = string
}

variable "backend_image_tag" {
  type = string
}

variable "media_bucket_name" {
  type = string
}

variable "media_base_url" {
  type = string
}

variable "backend_cors_origins" {
  type = string
}

variable "enable_custom_domains" {
  type    = bool
  default = false
}

variable "alb_certificate_arn" {
  description = "Regional ACM certificate ARN for HTTPS listener when custom domains are enabled"
  type        = string
  default     = null
}

variable "api_custom_domain" {
  description = "Custom API hostname when custom domains are enabled"
  type        = string
  default     = null
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
