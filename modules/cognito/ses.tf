data "aws_caller_identity" "current" {}

resource "aws_ses_domain_identity" "main" {
  count  = var.enable_ses_email ? 1 : 0
  domain = var.email_domain
}

resource "aws_ses_domain_dkim" "main" {
  count  = var.enable_ses_email ? 1 : 0
  domain = aws_ses_domain_identity.main[0].domain
}

resource "aws_route53_record" "ses_verification" {
  count   = var.enable_ses_email && var.manage_route53_records ? 1 : 0
  zone_id = var.route53_hosted_zone_id
  name    = "_amazonses.${var.email_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main[0].verification_token]
}

resource "aws_route53_record" "ses_dkim" {
  count   = var.enable_ses_email && var.manage_route53_records ? 3 : 0
  zone_id = var.route53_hosted_zone_id
  name    = "${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_ses_identity_policy" "cognito" {
  count    = var.enable_ses_email ? 1 : 0
  identity = aws_ses_domain_identity.main[0].arn
  name     = "${local.name_prefix}-cognito-send"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCognitoSend"
      Effect = "Allow"
      Principal = {
        Service = "cognito-idp.amazonaws.com"
      }
      Action   = "ses:SendEmail"
      Resource = aws_ses_domain_identity.main[0].arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = aws_cognito_user_pool.main.arn
        }
      }
    }]
  })
}
