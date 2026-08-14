# SES production access — minimal-cost setup

MotorClub uses Amazon SES in **eu-central-1** only for **transactional** Cognito emails (signup verification, password reset). This doc covers DNS, monitoring, abuse protection, simulator tests, and the production access request.

## What Terraform manages

| Resource | Cost |
|----------|------|
| SPF + DMARC DNS (Route 53) | $0 |
| SES configuration set + SNS + log Lambda | ~$0–1/mo |
| DynamoDB rate-limit table (PAY_PER_REQUEST) | ~$0 |
| Account suppression (bounce + complaint) | $0 |

## DNS records (motorclub.co.il)

- **SPF** (TXT on root): `v=spf1 include:amazonses.com ~all`
- **DMARC** (TXT on `_dmarc`): `v=DMARC1; p=none; rua=mailto:accounts@motorclub.co.il`
- **DKIM**: 3 CNAMEs (already managed by Terraform)

**Sender address:** `accounts@motorclub.co.il` (Cognito DEVELOPER mode)

## Simulator tests (sandbox)

Run from a machine with AWS CLI configured for account `240401023776`:

```bash
REGION=eu-central-1
FROM=accounts@motorclub.co.il

# Success
aws sesv2 send-email --region $REGION \
  --from-email-address "$FROM" \
  --destination "ToAddresses=success@simulator.amazonses.com" \
  --content "Simple={Subject={Data=MotorClub SES success test,Charset=UTF-8},Body={Text={Data=Simulator success test.,Charset=UTF-8}}}"

# Bounce
aws sesv2 send-email --region $REGION \
  --from-email-address "$FROM" \
  --destination "ToAddresses=bounce@simulator.amazonses.com" \
  --content "Simple={Subject={Data=MotorClub SES bounce test,Charset=UTF-8},Body={Text={Data=Simulator bounce test.,Charset=UTF-8}}}"

# Complaint
aws sesv2 send-email --region $REGION \
  --from-email-address "$FROM" \
  --destination "ToAddresses=complaint@simulator.amazonses.com" \
  --content "Simple={Subject={Data=MotorClub SES complaint test,Charset=UTF-8},Body={Text={Data=Simulator complaint test.,Charset=UTF-8}}}"
```

Verify events in CloudWatch:

```bash
aws logs tail /aws/lambda/motorclub-serverless-ses-events --region eu-central-1 --since 30m
```

## Production access request (submit manually)

**Mail type:** TRANSACTIONAL (not marketing)

**Use case:** Account verification and password reset for MotorClub IL (https://motorclub.co.il), a community app for car enthusiasts in Israel. We send only triggered emails via Amazon Cognito; no newsletters or promotional mail.

**Volume:** Low — estimated under 500 emails/month at launch, scaling with user signups.

**Recipient list:** Users who register on motorclub.co.il with double opt-in (email verification code required before login).

**Bounce/complaint handling:**

- Account-level suppression enabled (BOUNCE + COMPLAINT)
- SES configuration set with SNS → Lambda logging to CloudWatch
- DMARC aggregate reports to accounts@motorclub.co.il

**Abuse prevention:**

- Rate limits on `/auth/register`, `/auth/forgot-password`, `/auth/confirm` (DynamoDB, per IP and per email)
- No public “send email” API

**Website:** https://motorclub.co.il (privacy policy describes transactional email use)

**From address:** accounts@motorclub.co.il

Attach simulator test screenshots or CloudWatch log excerpts showing bounce/complaint events were received.

## After approval

Once `ProductionAccessEnabled` is true, Cognito verification emails will reach real inboxes without sandbox restrictions. No code changes required.

## Do not resubmit until

1. SPF + DMARC live in Route 53
2. Configuration set + event logging deployed
3. Sender changed to accounts@
4. Simulator tests completed with log evidence
