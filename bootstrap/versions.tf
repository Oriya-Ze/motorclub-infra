terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "MotorClub"
      Environment = "shared"
      ManagedBy   = "Terraform"
      Component   = "bootstrap"
    }
  }
}
