variable "aws_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Infrastructure slug used in resource naming"
  type        = string
  default     = "motorclub"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state"
  type        = string
  default     = "motorclub-terraform-state"
}
