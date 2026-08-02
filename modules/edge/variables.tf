variable "project_name" {
  type = string
}

variable "environment" {
  type = string
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

variable "domain_name" {
  description = "Root domain name used when custom domains are enabled"
  type        = string
  default     = "motorclub.co.il"
}

variable "frontend_custom_domains" {
  type    = list(string)
  default = []
}

variable "media_custom_domain" {
  type    = string
  default = null
}

variable "api_custom_domain" {
  type    = string
  default = null
}

variable "frontend_bucket_id" {
  type = string
}

variable "frontend_bucket_arn" {
  type = string
}

variable "frontend_bucket_regional_domain_name" {
  type = string
}

variable "media_bucket_id" {
  type = string
}

variable "media_bucket_arn" {
  type = string
}

variable "media_bucket_regional_domain_name" {
  type = string
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
