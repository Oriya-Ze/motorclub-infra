module "network" {
  source = "../../modules/network"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

module "database" {
  source = "../../modules/database"

  project_name          = var.project_name
  environment           = var.environment
  private_db_subnet_ids = module.network.private_db_subnet_ids
  rds_security_group_id = module.network.rds_security_group_id
  instance_class        = var.db_instance_class
  multi_az              = false
  deletion_protection   = false
  skip_final_snapshot   = true
}

module "storage" {
  source = "../../modules/storage"

  project_name               = var.project_name
  environment                = var.environment
  media_cors_allowed_origins = var.allow_broad_media_cors_in_dev && !var.enable_custom_domains ? ["*"] : []
}

module "iam" {
  source = "../../modules/iam"

  project_name           = var.project_name
  environment            = var.environment
  media_bucket_arn       = module.storage.media_bucket_arn
  database_secret_arn    = module.database.database_secret_arn
  application_secret_arn = module.database.application_secret_arn
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
  api_custom_domain                    = var.api_custom_domain
  frontend_bucket_id                   = module.storage.frontend_bucket_name
  frontend_bucket_arn                  = module.storage.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.storage.frontend_bucket_regional_domain_name
  media_bucket_id                      = module.storage.media_bucket_name
  media_bucket_arn                     = module.storage.media_bucket_arn
  media_bucket_regional_domain_name    = module.storage.media_bucket_regional_domain_name
  enable_waf                           = var.enable_waf
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

module "compute" {
  source = "../../modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids
  alb_security_group_id  = module.network.alb_security_group_id
  ecs_security_group_id  = module.network.ecs_security_group_id
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn      = module.iam.ecs_task_role_arn
  database_secret_arn    = module.database.database_secret_arn
  application_secret_arn = module.database.application_secret_arn
  backend_image_tag      = var.backend_image_tag
  media_bucket_name      = module.storage.media_bucket_name
  media_base_url         = module.edge.media_url
  backend_cors_origins   = module.edge.frontend_url
  enable_custom_domains  = var.enable_custom_domains
  alb_certificate_arn = var.enable_custom_domains ? (
    var.manage_route53_records ? aws_acm_certificate_validation.api[0].certificate_arn : aws_acm_certificate.api[0].arn
  ) : null
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = var.enable_custom_domains && var.manage_route53_records ? {
    for dvo in aws_acm_certificate.api[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = var.route53_hosted_zone_id
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

resource "aws_route53_record" "api" {
  count = var.enable_custom_domains && var.manage_route53_records ? 1 : 0

  zone_id = var.route53_hosted_zone_id
  name    = var.api_custom_domain
  type    = "A"

  alias {
    name                   = module.compute.alb_dns_name
    zone_id                = module.compute.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_wafv2_web_acl" "alb" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-${var.environment}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-alb-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-alb-rate"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-alb-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf ? 1 : 0

  resource_arn = module.compute.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn
}

locals {
  api_url = var.enable_custom_domains ? "https://${var.api_custom_domain}" : "http://${module.compute.alb_dns_name}"
}
