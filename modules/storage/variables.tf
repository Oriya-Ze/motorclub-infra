variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "media_cors_allowed_origins" {
  description = "Browser origins allowed to PUT directly to the media bucket"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
