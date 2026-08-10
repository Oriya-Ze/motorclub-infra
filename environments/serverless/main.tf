locals {
  route53_zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : var.route53_hosted_zone_id

  frontend_cors_origins = var.enable_custom_domains ? join(",", [
    for domain in var.frontend_custom_domains : "https://${domain}"
  ]) : null

  media_cors_origins = var.enable_custom_domains ? [
    for domain in var.frontend_custom_domains : "https://${domain}"
  ] : (var.allow_broad_media_cors ? ["*"] : [])
}

resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name = var.domain_name

  tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "dns"
  }
}

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

resource "aws_acm_certificate" "api" {
  count = var.enable_custom_domains ? 1 : 0

  domain_name       = var.api_custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "edge"
  }
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = var.enable_custom_domains && var.manage_route53_records ? {
    for dvo in aws_acm_certificate.api[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = local.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "api" {
  count = var.enable_custom_domains && var.manage_route53_records ? 1 : 0

  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

module "storage" {
  source = "../../modules/storage"

  project_name               = var.project_name
  environment                = var.environment
  media_cors_allowed_origins = local.media_cors_origins
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
  route53_hosted_zone_id               = local.route53_zone_id
  domain_name                          = var.domain_name
  frontend_custom_domains              = var.frontend_custom_domains
  media_custom_domain                  = var.media_custom_domain
  api_custom_domain                    = var.api_custom_domain
  frontend_bucket_id                   = module.storage.frontend_bucket_name
  frontend_bucket_arn                  = module.storage.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.storage.frontend_bucket_regional_domain_name
  media_bucket_id                      = module.storage.media_bucket_name
  media_bucket_arn                     = module.storage.media_bucket_arn
  media_bucket_regional_domain_name    = module.storage.media_bucket_regional_domain_name
  enable_waf                           = var.enable_waf
}

module "cognito" {
  source = "../../modules/cognito"

  project_name              = var.project_name
  environment               = var.environment
  cognito_domain_prefix     = var.cognito_domain_prefix
  google_client_id          = var.google_oauth_client_id
  google_client_secret      = var.google_oauth_client_secret
  extra_oauth_callback_urls = ["${module.edge.frontend_url}/auth/callback"]
  extra_oauth_logout_urls   = [module.edge.frontend_url]

  enable_ses_email         = var.enable_custom_domains
  email_domain             = var.domain_name
  from_email_address       = "noreply@${var.domain_name}"
  route53_hosted_zone_id   = local.route53_zone_id
  manage_route53_records   = var.manage_route53_records
}

module "lambda_api" {
  source = "../../modules/lambda_api"

  project_name         = var.project_name
  environment          = var.environment
  auth_provider        = "cognito"
  image_uri            = "${aws_ecr_repository.api.repository_url}:${var.lambda_image_tag}"
  database_url         = var.database_url
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_user_pool_arn = module.cognito.user_pool_arn
  cognito_client_id    = module.cognito.client_id
  cognito_client_secret = module.cognito.client_secret
  cognito_domain       = module.cognito.cognito_domain
  backend_cors_origins = local.frontend_cors_origins != null ? local.frontend_cors_origins : module.edge.frontend_url
  media_bucket_name    = module.storage.media_bucket_name
  media_base_url       = module.edge.media_url
  memory_size          = var.lambda_memory_size
  timeout              = var.lambda_timeout
  api_custom_domain        = var.enable_custom_domains ? var.api_custom_domain : null
  enable_api_custom_domain = var.enable_custom_domains
  api_certificate_arn = var.enable_custom_domains ? (
    var.manage_route53_records ? aws_acm_certificate_validation.api[0].certificate_arn : aws_acm_certificate.api[0].arn
  ) : null
}

resource "aws_route53_record" "api" {
  count = var.enable_custom_domains && var.manage_route53_records ? 1 : 0

  zone_id = local.route53_zone_id
  name    = var.api_custom_domain
  type    = "A"

  alias {
    name                   = module.lambda_api.api_domain_target_domain_name
    zone_id                = module.lambda_api.api_domain_hosted_zone_id
    evaluate_target_health = false
  }
}
