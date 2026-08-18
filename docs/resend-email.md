# Cognito auth emails via Resend

Replaces Amazon SES for Cognito verification and password-reset emails when SES sandbox/production access is unavailable.

## Flow

```
User registers / forgot password
        → Cognito generates code (encrypted with KMS)
        → Lambda `motorclub-serverless-cognito-resend-email`
        → Resend API
        → accounts@motorclub.co.il
```

## Prerequisites

1. **Resend** — domain `motorclub.co.il` verified
2. **Secrets Manager** — secret `motorclub/prod/resend` with the Resend API key (plain `re_...` string or JSON `{"RESEND_API_KEY":"re_..."}`)
3. **Python 3 + pip** on the machine running `terraform apply` (builds the Lambda zip)

## Terraform

In `environments/serverless/terraform.tfvars`:

```hcl
enable_custom_domains = true
enable_resend_email   = true   # default: true
resend_secret_name    = "motorclub/prod/resend"
```

SES is disabled automatically when Resend is enabled.

## Deploy

```bash
cd motorclub-infra/environments/serverless
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

The Cognito module runs `scripts/build-resend-lambda.sh` before creating/updating the Lambda.

## Test

1. Register a new user on https://motorclub.co.il/auth
2. Check inbox for Hebrew verification email from `MotorClub <accounts@motorclub.co.il>`
3. Forgot password flow — same sender

## Logs

CloudWatch: `/aws/lambda/motorclub-serverless-cognito-resend-email`

## Cost

| Component | Typical cost |
|-----------|--------------|
| Lambda | ~$0 (low volume) |
| KMS | ~$1/month |
| Resend | Free tier: 3,000 emails/month |
