# Serverless stack: Lambda + Neon + S3 + CloudFront

Low-cost alternative to the full ECS/RDS dev stack (~$0–15/month at low traffic).

## Architecture

| Component | Service |
|-----------|---------|
| API | AWS Lambda (container image) + API Gateway HTTP API |
| **Authentication** | **AWS Cognito User Pool** (email + password) |
| App database | [Neon](https://neon.tech) PostgreSQL (`users.cognito_sub` links to Cognito) |
| Frontend | S3 + CloudFront |
| Media uploads | S3 presigned URLs + CloudFront CDN |

No VPC, NAT, ALB, RDS, or ECS.

## Prerequisites

- AWS CLI configured (account `376129883917` or your own)
- Terraform **1.10.5+**
- Remote state bucket bootstrapped (`motorclub-terraform-state`)
- Neon project with PostgreSQL 16+
- Docker (to build the Lambda container image)

## 1. Create Neon database

1. Sign up at [neon.tech](https://neon.tech) and create a project (e.g. `motorclub-serverless`).
2. Copy the **pooled** connection string and convert it for async SQLAlchemy:

   ```
   postgresql+asyncpg://USER:PASSWORD@ep-xxx.eu-central-1.aws.neon.tech/neondb?ssl=require
   ```

   Neon’s default URI uses `postgresql://` — change the scheme to `postgresql+asyncpg://` and append `?ssl=require`.

3. Store the URL locally; you will pass it as `database_url` in Terraform (never commit it).

## 2. Run Alembic migrations against Neon

From the `motorclub` repo:

```bash
cd backend
export DATABASE_URL="postgresql+asyncpg://USER:PASSWORD@HOST/DB?ssl=require"
export ENVIRONMENT=local
alembic upgrade head
```

Use `ENVIRONMENT=local` when running migrations from your laptop (only `DATABASE_URL` is needed). Do not set `ENVIRONMENT=dev` unless you also provide `BACKEND_CORS_ORIGINS` and other production env vars.

Migrations run **outside** Lambda (CI, laptop, or GitHub Actions). Do not run Alembic on every cold start.

Optional seed:

```bash
python -m app.seed
```

## 3. Bootstrap Terraform backend

If not done already:

```bash
cd bootstrap
terraform init
terraform apply -var='state_bucket_name=motorclub-terraform-state'
```

Copy backend config:

```bash
cp environments/serverless/backend.hcl.example environments/serverless/backend.hcl
# Edit bucket name
```

## 4. Build and push Lambda image

Push **before** the first `terraform apply` (Lambda needs an image in ECR).

```bash
cd motorclub
GIT_SHA=$(git rev-parse --short HEAD)
AWS_REGION=eu-central-1

# After first init/apply you can read this from Terraform output:
ECR_URL=$(terraform -chdir=../motorclub-infra/environments/serverless output -raw ecr_api_repository_url 2>/dev/null || echo "")

if [ -z "$ECR_URL" ]; then
  # First-time: create ECR repo manually or run terraform apply -target=aws_ecr_repository.api
  ECR_URL="240401023776.dkr.ecr.eu-central-1.amazonaws.com/motorclub-api-lambda"
fi

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${ECR_URL%/*}"

docker build -f backend/Dockerfile.lambda -t "${ECR_URL}:${GIT_SHA}" backend
docker push "${ECR_URL}:${GIT_SHA}"
```

**First apply tip:** If ECR does not exist yet, run a targeted apply:

```bash
cd motorclub-infra/environments/serverless
terraform init -backend-config=backend.hcl
terraform apply -target=aws_ecr_repository.api -target=aws_ecr_lifecycle_policy.api
```

Then build/push the image and apply the full stack.

## 5. Deploy infrastructure

```bash
cd motorclub-infra/environments/serverless
cp terraform.tfvars.example terraform.tfvars
# Edit: lambda_image_tag, database_url

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## 6. Smoke test

```bash
API_URL=$(terraform output -raw api_url)
curl -s "${API_URL}/health" | jq .
curl -s "${API_URL}/health/ready" | jq .
```

Build frontend with outputs:

```bash
terraform output -json frontend_build_env
# VITE_API_URL, VITE_MEDIA_BASE_URL
```

Upload frontend to the S3 bucket (`frontend_bucket_name` output) and invalidate CloudFront (`frontend_distribution_id`).

## Environment variables (Lambda)

Set automatically by Terraform (`modules/lambda_api` + `modules/cognito`):

| Variable | Source |
|----------|--------|
| `AUTH_PROVIDER` | `cognito` |
| `COGNITO_USER_POOL_ID` | Cognito module |
| `COGNITO_CLIENT_ID` | Cognito module |
| `COGNITO_CLIENT_SECRET` | Cognito module (confidential app client) |
| `DATABASE_URL` | Neon (tfvars) |
| `MEDIA_STORAGE_PROVIDER` | `s3` |
| `S3_MEDIA_BUCKET` | storage module |
| `MEDIA_BASE_URL` | CloudFront media URL |
| `BACKEND_CORS_ORIGINS` | CloudFront frontend URL |
| `ENVIRONMENT` | `serverless` |

`AWS_REGION` is provided by the Lambda runtime (used by boto3 for Cognito and S3).

## User registration flow (Cognito)

1. User registers via frontend → `POST /auth/register` → Cognito `SignUp`
2. Cognito sends a verification code to the user's email (COGNITO_DEFAULT sender; fine for early access)
3. User enters code → `POST /auth/confirm` → Cognito `ConfirmSignUp` + login
4. On first login, Lambda creates the app user row in Neon linked by `cognito_sub`

Forgot password uses Cognito's built-in flow (`/auth/forgot-password`, `/auth/reset-password`).

Email is sent via **Amazon SES** from `noreply@motorclub.co.il` when custom domains are enabled (`enable_custom_domains = true` in Terraform). Cognito handles verification codes and password-reset emails automatically.

### SES setup (production)

Terraform in `modules/cognito/ses.tf` creates:

1. SES domain identity for `motorclub.co.il`
2. Route 53 TXT + DKIM CNAME records (when `manage_route53_records = true`)
3. IAM policy allowing Cognito to send via SES
4. Cognito `email_configuration` with `from_email_address = "noreply@motorclub.co.il"`

**Before wide launch:** request [SES production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) to exit the sandbox (required to email arbitrary user addresses).

Optionally add SPF on the root domain: `v=spf1 include:amazonses.com ~all`

No backend or frontend code changes are required for email delivery.

## Updating the API

1. Build and push a new image tag (Git SHA).
2. `terraform apply -var="lambda_image_tag=${GIT_SHA}"`
3. Run Alembic if schema changed.

## Cost estimate (low traffic)

| Service | Approx. |
|---------|---------|
| Lambda + API Gateway | $0–5 |
| Cognito | $0 (free tier ~10K MAU) |
| S3 + CloudFront | $1–5 |
| Neon free tier | $0 |
| **Total** | **~$0–15/month** |

## Coexistence with ECS dev stack

The `serverless` environment uses a **separate Terraform state key** (`serverless/terraform.tfstate`) and `environment = "serverless"` resource names. It does not conflict with `environments/dev` (ECS/RDS).

## CI (future)

Extend `.github/workflows/terraform-ci.yml` with a `plan-serverless` job and optional apply workflow, mirroring dev.
