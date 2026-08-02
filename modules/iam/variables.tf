variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "media_bucket_arn" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "application_secret_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
