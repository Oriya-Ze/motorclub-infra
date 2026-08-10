# MotorClub AWS infrastructure (`motorclub-infra`)

Terraform for the **MotorClub** platform. This repository is separate from the application repository [`motorclub`](../motorclub).

## Repositories

| Repository | Purpose |
|------------|---------|
| `motorclub` | FastAPI backend, React frontend, Docker, Alembic, local Compose |
| `motorclub-infra` | AWS infrastructure (this repo) |

## Initial deployment (no custom DNS)

The first deployment **does not** change nameservers or create Route 53 records for `motorclub.co.il`.

Use AWS-generated endpoints for smoke tests:

| Output | Use |
|--------|-----|
| `frontend_cloudfront_domain` / `frontend_url` | React SPA (HTTPS via CloudFront) |
| `media_cloudfront_domain` / `media_url` | Media CDN (HTTPS via CloudFront) |
| `alb_dns_name` / `api_url` | API smoke tests (**HTTP** on ALB DNS — temporary, not the final public API endpoint) |

Custom domains, ACM certificates, and Route 53 records are gated by:

```hcl
enable_custom_domains   = false  # default
manage_route53_records  = false  # default
```

## Prerequisites

- AWS CLI configured
- Terraform **1.10.5** (see `.terraform-version`; required for S3 native state locking with `use_lockfile`)
- An ECR image tag ready in `motorclub` (Git SHA; do **not** use `latest`)

## Bootstrap remote state (one time)

```bash
cd bootstrap
terraform init
terraform apply -var='state_bucket_name=motorclub-terraform-state-YOUR_ACCOUNT_ID'
```

Copy `backend.hcl.example` to `environments/dev/backend.hcl` and set your bucket name.

## Deploy dev

```bash
cd environments/dev
terraform init -backend-config=backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set backend_image_tag

terraform plan
terraform apply
```

## Cross-repository workflow

### 1. Build and push backend image (`motorclub`)

```bash
cd ../motorclub
GIT_SHA=$(git rev-parse --short HEAD)
ECR_URL=$(terraform -chdir=../motorclub-infra/environments/dev output -raw ecr_backend_repository_url)

aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "${ECR_URL%/*}"
docker build -t "${ECR_URL}:${GIT_SHA}" ./backend
docker push "${ECR_URL}:${GIT_SHA}"
```

### 2. Apply infrastructure with image tag (`motorclub-infra`)

```bash
terraform -chdir=environments/dev apply -var="backend_image_tag=${GIT_SHA}"
```

### 3. Run Alembic migration (one-off ECS task)

```bash
./scripts/run-migration.sh \
  "$(terraform -chdir=environments/dev output -raw ecs_cluster_name)" \
  "$(terraform -chdir=environments/dev output -raw migration_task_definition_arn)" \
  "$(terraform -chdir=environments/dev output -json private_app_subnet_ids | python3 -c 'import json,sys; print(json.load(sys.stdin)[0])')" \
  "$(terraform -chdir=environments/dev output -raw ecs_security_group_id)"
```

Note: the ALB DNS name (`alb_dns_name` / `api_url`) is for **temporary HTTP smoke tests** only. It is not the final public API endpoint until custom domains and HTTPS are enabled.

### 4. Build frontend with Terraform outputs

```bash
eval "$(./scripts/print-frontend-build-env.sh)"
cd ../motorclub/frontend
npm run build
aws s3 sync dist/ "s3://$(terraform -chdir=../../motorclub-infra/environments/dev output -raw frontend_bucket_name)/"
```

## Database migrations

Migrations **never** run automatically on ECS service startup.

Safe order:

1. Register new task definition (via `terraform apply` with new `backend_image_tag`)
2. Run one-off task: `alembic upgrade head`
3. Wait for exit code 0
4. Deploy/update ECS service (same apply if task definition changed)

Phase 5 GitHub Actions will automate this sequence.

## Later DNS integration (`motorclub.co.il`)

When the AWS environment is validated:

1. Create or adopt a Route 53 hosted zone for `motorclub.co.il`
2. Set `enable_custom_domains = true`
3. Set `manage_route53_records = true` and `route53_hosted_zone_id`
4. Apply Terraform to request ACM certificates and create:
   - `motorclub.co.il` / `www.motorclub.co.il` → CloudFront frontend
   - `media.motorclub.co.il` → CloudFront media
   - `api.motorclub.co.il` → ALB (HTTPS)
5. **Only then** update domain nameservers at the registrar
6. Verify new records before removing old DNS configuration

If `manage_route53_records = false`, create ACM validation CNAMEs manually from Terraform outputs:

- `cloudfront_certificate_validation_records`
- `api_certificate_validation_records`

## Networking

- Single VPC, 2 AZs
- Public subnets: ALB
- Private app subnets: ECS (no public IP)
- Private DB subnets: RDS
- **No NAT Gateway** in dev — VPC endpoints for ECR, Logs, Secrets Manager, STS, and S3 gateway endpoint

## Module layout

```text
modules/network    VPC, subnets, endpoints, security groups
modules/database   RDS PostgreSQL, Secrets Manager
modules/storage    Frontend + media S3 buckets
modules/compute    ECR, ECS, ALB
modules/edge       CloudFront, optional ACM/Route53, optional WAF
modules/iam        ECS execution + task roles
modules/lambda_api Lambda container, API Gateway HTTP API, IAM
modules/cognito    Cognito User Pool + app client
```

## Serverless stack (Lambda + Neon)

Low-cost alternative (~$0–15/month). Separate state key and environment name — does not replace `environments/dev`.

See [docs/serverless-neon.md](docs/serverless-neon.md) for Neon setup, Lambda image build, and deploy steps.

```bash
cd environments/serverless
terraform init -backend-config=backend.hcl
terraform apply
```

## CI/CD

Phase 5 automation is documented in [docs/ci-cd.md](docs/ci-cd.md).

- **Phase 5A (implemented):** Terraform fmt, validate, and plan via `.github/workflows/terraform-ci.yml`
- **Later phases:** manually approved Terraform apply (infra only), application CI/deploy in `motorclub` — no Terraform on routine image deploys

## Secrets

Never commit:

- `terraform.tfvars` (real values)
- Terraform state
- AWS credentials
- Database passwords

JWT and database credentials live in Secrets Manager (`motorclub/dev/database`, `motorclub/dev/application`).
