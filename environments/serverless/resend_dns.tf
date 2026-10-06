# Resend domain verification DNS (motorclub.co.il)
# Required for API Lambda + Resend to send from accounts@motorclub.co.il

resource "aws_route53_record" "resend_dkim" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = local.route53_zone_id
  name    = "resend._domainkey.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = [
    "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCmJ9f63PCjDKsHKEcSOiG7iDszIkPbox7LzPRcDDz0vLKU3/hcMA2TURMlcfU3A16nxk1/NMswz5N+gW/W4Uxl7xyGd5WdvNEWj1nak0x5gJw1+hOkKxhEzmSQtT6STs8x9QtX/o3VRYVD0oHAn9Q2xCHyR3DV+qOBZREAGyzOuwIDAQAB",
  ]
}

resource "aws_route53_record" "resend_send_mx" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = local.route53_zone_id
  name    = "send.${var.domain_name}"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

resource "aws_route53_record" "resend_send_spf" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = local.route53_zone_id
  name    = "send.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}
