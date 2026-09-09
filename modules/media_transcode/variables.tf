variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "media_bucket_name" {
  type = string
}

variable "media_bucket_arn" {
  type = string
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "image_uri" {
  type = string
}

variable "memory_size" {
  type    = number
  default = 3008
}

variable "timeout" {
  type    = number
  default = 900
}

variable "tags" {
  type    = map(string)
  default = {}
}
