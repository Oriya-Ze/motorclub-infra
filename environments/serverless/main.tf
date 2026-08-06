resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-api-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "lambda-api"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

module "cognito" {
  source = "../../modules/cognito"

  project_name = var.project_name
  environment  = var.environment
}

module "storage" {
  source = "../../modules/storage"

  project_name               = var.project_name
  environment                = var.environment
  media_cors_allowed_origins = var.allow_broad_media_cors && !var.enable_custom_domains ? ["*"] : []
}

module "edge" {
  source = "../../modules/edge"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name                         = var.project_name
  environment                          = var.environment
  enable_custom_domains                = var.enable_custom_domains
  manage_route53_records               = var.manage_route53_records
  route53_hosted_zone_id               = var.route53_hosted_zone_id
  domain_name                          = var.domain_name
  frontend_custom_domains              = var.frontend_custom_domains
  media_custom_domain                  = var.media_custom_domain
  api_custom_domain                    = null
  frontend_bucket_id                   = module.storage.frontend_bucket_name
  frontend_bucket_arn                  = module.storage.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.storage.frontend_bucket_regional_domain_name
  media_bucket_id                      = module.storage.media_bucket_name
  media_bucket_arn                     = module.storage.media_bucket_arn
  media_bucket_regional_domain_name    = module.storage.media_bucket_regional_domain_name
  enable_waf                           = var.enable_waf
}

module "lambda_api" {
  source = "../../modules/lambda_api"

  project_name            = var.project_name
  environment             = var.environment
  auth_provider           = "cognito"
  image_uri               = "${aws_ecr_repository.api.repository_url}:${var.lambda_image_tag}"
  database_url            = var.database_url
  cognito_user_pool_id    = module.cognito.user_pool_id
  cognito_user_pool_arn   = module.cognito.user_pool_arn
  cognito_client_id       = module.cognito.client_id
  cognito_client_secret   = module.cognito.client_secret
  backend_cors_origins    = module.edge.frontend_url
  media_bucket_name       = module.storage.media_bucket_name
  media_base_url          = module.edge.media_url
  memory_size             = var.lambda_memory_size
  timeout                 = var.lambda_timeout
}
