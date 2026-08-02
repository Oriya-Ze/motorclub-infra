provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "MotorClub"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "MotorClub"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
