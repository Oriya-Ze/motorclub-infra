variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "motorclub"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "backend_image_tag" {
  description = "Immutable backend image tag, preferably a Git commit SHA"
  type        = string
}

variable "enable_custom_domains" {
  description = "Enable ACM certificates and custom domain configuration"
  type        = bool
  default     = false
}

variable "manage_route53_records" {
  description = "Create DNS records in an existing Route 53 hosted zone"
  type        = bool
  default     = false
}

variable "route53_hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID, required only when Route 53 record management is enabled"
  type        = string
  default     = null
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

variable "allow_broad_media_cors_in_dev" {
  description = "Allow '*' CORS on the media bucket until a specific frontend origin is known"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

check "route53_hosted_zone_required" {
  assert {
    condition     = !var.manage_route53_records || (var.route53_hosted_zone_id != null && var.route53_hosted_zone_id != "")
    error_message = "route53_hosted_zone_id must be set when manage_route53_records is true."
  }
}
