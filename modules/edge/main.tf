locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "edge"
  })

  frontend_aliases = var.enable_custom_domains ? var.frontend_custom_domains : []
  media_alias      = var.enable_custom_domains && var.media_custom_domain != null ? [var.media_custom_domain] : []

  www_host = "www.${var.domain_name}"
  canonical_frontend_host = var.enable_custom_domains && length(var.frontend_custom_domains) > 0 ? (
    contains(var.frontend_custom_domains, local.www_host) ? local.www_host : var.frontend_custom_domains[0]
  ) : ""
  frontend_url = var.enable_custom_domains && local.canonical_frontend_host != "" ? "https://${local.canonical_frontend_host}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
  media_url    = var.enable_custom_domains && var.media_custom_domain != null ? "https://${var.media_custom_domain}" : "https://${aws_cloudfront_distribution.media.domain_name}"
}

resource "aws_cloudfront_function" "redirect_www" {
  count = var.enable_custom_domains ? 1 : 0

  name    = "${local.name_prefix}-redirect-www"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect apex to www, except service worker files"
  publish = true
  code = templatefile("${path.module}/functions/redirect-www.js", {
    apex_host = var.domain_name
    www_host  = local.www_host
  })
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend-oac"
  description                       = "OAC for ${local.name_prefix} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "media" {
  name                              = "${local.name_prefix}-media-oac"
  description                       = "OAC for ${local.name_prefix} media bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "cloudfront" {
  count = var.enable_custom_domains ? 1 : 0

  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = compact(concat(var.frontend_custom_domains, [var.media_custom_domain]))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-cert"
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domains && var.manage_route53_records ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "cloudfront" {
  count = var.enable_custom_domains && var.manage_route53_records ? 1 : 0

  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Browser security headers for the site. No Content-Security-Policy yet: the app loads Google
# Fonts, media, and API calls from other hosts, and a CSP needs testing against all of them.
resource "aws_cloudfront_response_headers_policy" "frontend_security" {
  name    = "${local.name_prefix}-frontend-security"
  comment = "HSTS, nosniff, no framing, referrer and permissions policy for the site"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), microphone=(), payment=(), usb=()"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  lifecycle {
    prevent_destroy = true
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${local.name_prefix} frontend"
  aliases             = local.frontend_aliases

  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "frontend-s3"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.frontend_security.id

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    dynamic "function_association" {
      for_each = var.enable_custom_domains ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www[0].arn
      }
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.enable_custom_domains
    acm_certificate_arn = var.enable_custom_domains ? (
      var.manage_route53_records ? aws_acm_certificate_validation.cloudfront[0].certificate_arn : aws_acm_certificate.cloudfront[0].arn
    ) : null
    ssl_support_method       = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend-cf"
  })
}

resource "aws_cloudfront_distribution" "media" {
  lifecycle {
    prevent_destroy = true
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name_prefix} media"
  aliases         = local.media_alias

  origin {
    domain_name              = var.media_bucket_regional_domain_name
    origin_id                = "media-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.media.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "media-s3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.enable_custom_domains
    acm_certificate_arn = var.enable_custom_domains ? (
      var.manage_route53_records ? aws_acm_certificate_validation.cloudfront[0].certificate_arn : aws_acm_certificate.cloudfront[0].arn
    ) : null
    ssl_support_method       = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-media-cf"
  })
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid    = "AllowCloudFrontServiceRead"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.frontend_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id
  policy = data.aws_iam_policy_document.frontend_bucket.json
}

data "aws_iam_policy_document" "media_bucket" {
  statement {
    sid    = "AllowCloudFrontServiceRead"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.media_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.media.arn]
    }
  }

  statement {
    sid    = "DenyCloudFrontPrivateMedia"
    effect = "Deny"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.media_bucket_arn}/users/*/private/*"]
  }
}

resource "aws_s3_bucket_policy" "media" {
  bucket = var.media_bucket_id
  policy = data.aws_iam_policy_document.media_bucket.json
}

resource "aws_route53_record" "frontend" {
  for_each = var.enable_custom_domains && var.manage_route53_records ? toset(var.frontend_custom_domains) : toset([])

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "media" {
  count = var.enable_custom_domains && var.manage_route53_records && var.media_custom_domain != null ? 1 : 0

  zone_id = var.route53_hosted_zone_id
  name    = var.media_custom_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.media.domain_name
    zone_id                = aws_cloudfront_distribution.media.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_wafv2_web_acl" "cloudfront" {
  count = var.enable_waf ? 1 : 0

  provider = aws.us_east_1

  name  = "${local.name_prefix}-cloudfront-waf"
  scope = "CLOUDFRONT"

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
      metric_name                = "${local.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-bad-inputs"
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
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "frontend" {
  count = var.enable_waf ? 1 : 0

  provider = aws.us_east_1

  resource_arn = aws_cloudfront_distribution.frontend.arn
  web_acl_arn  = aws_wafv2_web_acl.cloudfront[0].arn
}

resource "aws_wafv2_web_acl_association" "media" {
  count = var.enable_waf ? 1 : 0

  provider = aws.us_east_1

  resource_arn = aws_cloudfront_distribution.media.arn
  web_acl_arn  = aws_wafv2_web_acl.cloudfront[0].arn
}
