# MotorClub CI/CD

This document describes GitHub Actions and AWS OIDC setup for the MotorClub platform.

Infrastructure deployment (Terraform) and application deployment (ECS, S3, CloudFront) are **separate**. See [Phase structure](#phase-structure) below.

Application repository: [`motorclub`](https://github.com/Oriya-Ze/motorclub)  
Infrastructure repository: [`motorclub-infra`](https://github.com/Oriya-Ze/motorclub-infra) (this repo)

---

## Phase structure

| Phase | Repository | Status | Purpose |
|-------|------------|--------|---------|
| **5A** | `motorclub-infra` | Implemented | Terraform fmt, validate, plan on PR/push |
| **5B** | `motorclub-infra` | Planned | Manually approved `terraform apply` (`environment: dev`) |
| **5C** | `motorclub` | Planned | Application CI (tests, build checks; no AWS) |
| **5D** | `motorclub` | Planned | Manual backend deploy (ECR, task def, migration, ECS update) |
| **5E** | `motorclub` | Planned | Manual frontend deploy (S3 sync, CloudFront invalidation) |

Cross-repository automation, automatic deploy on push, and PAT-based triggers are **out of scope** for the initial iteration.

---

## Terraform version and S3 state locking

This repository pins **Terraform 1.10.5** consistently in:

- `.terraform-version`
- `required_version` in Terraform configurations
- `.github/workflows/terraform-ci.yml` (`hashicorp/setup-terraform`)

S3 native state locking via `use_lockfile = true` (see `environments/dev/backend.hcl.example`) requires **Terraform 1.10 or later**. Do not use Terraform 1.9.x with `use_lockfile`.

Install locally:

```bash
# e.g. with tfenv
tfenv install 1.10.5
tfenv use 1.10.5
```

---

## OIDC architecture (manual setup)

Use **exactly one** GitHub OIDC provider per AWS account:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Do **not** create multiple GitHub OIDC providers. Do **not** use long-lived AWS access keys in GitHub.

### IAM roles

| Role | Repository | Used by |
|------|------------|---------|
| `motorclub-github-terraform-dev` | `Oriya-Ze/motorclub-infra` | Terraform CI plan (5A), Terraform apply (5B) |
| `motorclub-github-app-deploy-dev` | `Oriya-Ze/motorclub` | Backend deploy (5D), frontend deploy (5E) |

The application role is shared initially; it may be split into separate backend/frontend roles later.

---

## OIDC trust policies

Trust policies must match **how each workflow authenticates**. Branch-scoped and environment-scoped jobs use different `sub` claim values — do not mix them without updating the role trust policy.

### GitHub `sub` claim formats

GitHub Actions OIDC tokens include a `sub` (subject) claim. GitHub may emit **either** of these formats for the same repository:

| Format | Example (`main` branch push) |
|--------|------------------------------|
| Legacy (name only) | `repo:Oriya-Ze/motorclub-infra:ref:refs/heads/main` |
| With owner/repo IDs | `repo:Oriya-Ze@189972747/motorclub-infra@1320294367:ref:refs/heads/main` |

MotorClub `motorclub-infra` IDs (verified in CloudTrail, August 2026):

- Owner: `Oriya-Ze@189972747`
- Repository: `motorclub-infra@1320294367`

Trust policies that match only the legacy format will fail with:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

even when the role ARN, audience, and OIDC provider thumbprints are correct.

To find the `sub` value for a failed run, inspect **CloudTrail** → `AssumeRoleWithWebIdentity` events, or enable debug logging on the `configure-aws-credentials` step and compare to the IAM role trust policy.

### Branch-scoped jobs (Phase 5A — `terraform-ci.yml`)

Used by the `plan-dev` job. This workflow does **not** use the protected `dev` GitHub Environment. Allow **both** `sub` formats:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:Oriya-Ze/motorclub-infra:*",
            "repo:Oriya-Ze@189972747/motorclub-infra@1320294367:*"
          ]
        }
      }
    }
  ]
}
```

For pull requests from forks, GitHub OIDC tokens use a different subject; fork PR plans will not assume this role unless you add an explicit (carefully reviewed) trust rule. Phase 5A does not run `plan-dev` on pull requests.

Optional tightening for PR workflows from the same repo (not used in Phase 5A):

```text
repo:Oriya-Ze/motorclub-infra:pull_request
repo:Oriya-Ze@189972747/motorclub-infra@1320294367:pull_request
```

Document any PR trust rules you add in IAM before enabling them.

### Environment-scoped jobs (Phase 5B apply, 5D/5E deploy)

Workflows that set `environment: dev` receive a subject such as:

```text
repo:Oriya-Ze/motorclub-infra:environment:dev
repo:Oriya-Ze@189972747/motorclub-infra@1320294367:environment:dev
```

Example trust condition for **Terraform apply** (5B) — allow both formats:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": [
    "repo:Oriya-Ze/motorclub-infra:environment:dev",
    "repo:Oriya-Ze@189972747/motorclub-infra@1320294367:environment:dev"
  ]
}
```

Example trust condition for **application deploy** (5D/5E) on `motorclub` — replace owner/repo IDs after the first failed or successful deploy (from CloudTrail):

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": [
    "repo:Oriya-Ze/motorclub:environment:dev",
    "repo:Oriya-Ze@189972747/motorclub@REPO_ID:environment:dev"
  ]
}
```

**Summary**

| Workflow | GitHub Environment | OIDC `sub` (examples) |
|----------|-------------------|------------------------|
| `terraform-ci.yml` → `plan-dev` | none (repo variables) | `repo:Oriya-Ze/motorclub-infra:ref:refs/heads/main` **or** `repo:Oriya-Ze@189972747/motorclub-infra@1320294367:ref:refs/heads/main` |
| `terraform-apply-dev.yml` (5B) | `dev` | `repo:Oriya-Ze/motorclub-infra:environment:dev` **or** `repo:Oriya-Ze@189972747/motorclub-infra@1320294367:environment:dev` |
| Backend/frontend deploy (5D/5E) | `dev` | `repo:Oriya-Ze/motorclub:environment:dev` **or** ID-qualified equivalent |

---

## IAM permissions

### `motorclub-github-terraform-dev`

Attach least-privilege policies covering what the **dev Terraform configuration** requires, including:

- S3: read/write/list on the Terraform state bucket and state key prefix
- S3: lockfile object access when `use_lockfile = true`
- Resources created by modules: VPC, subnets, endpoints, security groups, RDS, Secrets Manager secrets used by Terraform, S3 buckets, CloudFront, ECS cluster/service/task definition baseline, ALB, ECR repository, IAM roles for ECS tasks, CloudWatch log groups, optional ACM/Route53/WAF when enabled

The role must **not** be used by the application repository.

### `motorclub-github-app-deploy-dev`

Allow **only** actions required for application deployment:

- ECR: login and push to the `motorclub-backend` repository
- ECS: describe/register task definitions, run one-off tasks, update service, wait for stability on the MotorClub dev cluster/service
- `iam:PassRole` for the **exact** ECS execution role and task role ARNs only
- S3: sync to the **exact** frontend bucket
- CloudFront: create invalidation on the **exact** frontend distribution
- Read deployment metadata (task definitions, service state, health endpoints)

Must **not** be able to create or modify:

- VPCs, subnets, RDS, IAM roles/policies, Route 53 zones
- Terraform state buckets
- Unrelated S3 buckets, ECR repos, ECS clusters/services, CloudFront distributions

Document the final JSON policy documents in IAM when you create the roles.

---

## GitHub configuration

### Repository variables — `motorclub-infra` (Phase 5A Terraform CI)

Configure under **Settings → Secrets and variables → Actions → Variables** (repository level, **not** the protected `dev` environment):

| Variable | Example | Purpose |
|----------|---------|---------|
| `AWS_REGION` | `eu-central-1` | AWS region |
| `AWS_TERRAFORM_ROLE_ARN` | `arn:aws:iam::123456789012:role/motorclub-github-terraform-dev` | OIDC role for Terraform CI |
| `TF_STATE_BUCKET` | `motorclub-terraform-state-123456789012` | Remote state bucket |
| `TF_STATE_KEY` | `dev/terraform.tfstate` | State object key |
| `TF_STATE_REGION` | `eu-west-1` | State bucket region |
| `TF_BACKEND_IMAGE_TAG` | `abc1234` | Current bootstrap/deployed backend image tag for plan |

The `plan-dev` job **fails with a clear message** if any of these are missing or empty.

#### Why `TF_BACKEND_IMAGE_TAG` is required

The dev Terraform configuration still accepts `backend_image_tag` for the ECS task definition image. That coupling is **transitional**. Routine application image deployments will move to the `motorclub` repository (Phase 5D) and will **not** use Terraform.

Until Terraform ownership of the image tag is removed, CI plan jobs must pass the **currently configured** tag so plans show infrastructure drift rather than a synthetic image change every run.

Do **not** use:

- `latest`
- `ci-${GITHUB_SHA}`
- the current PR commit SHA
- parsing `terraform state show` output

Update `TF_BACKEND_IMAGE_TAG` when an infrastructure apply intentionally changes the baseline image tag.

### Protected `dev` Environment (Phase 5B, 5D, 5E — not Phase 5A)

Create a GitHub Environment named **`dev`** with **required reviewers** for:

- Terraform apply (5B)
- Backend deployment (5D)
- Frontend deployment (5E)

**Phase 5A does not use `environment: dev`.** Terraform CI plan runs without deployment approval.

Environment variables for later application deploy workflows (non-sensitive):

```text
VITE_API_URL
VITE_MEDIA_BASE_URL
FRONTEND_S3_BUCKET
FRONTEND_CF_DISTRIBUTION_ID
API_HEALTH_URL
FRONTEND_URL
ECR_REPOSITORY_URL
ECS_CLUSTER_NAME
ECS_SERVICE_NAME
ECS_CONTAINER_NAME
```

For environment-scoped workflows (5B+), store the appropriate role ARN as a variable or secret on the `dev` environment, for example:

- `AWS_TERRAFORM_ROLE_ARN` on `motorclub-infra` environment `dev` (apply)
- `AWS_APP_DEPLOY_ROLE_ARN` on `motorclub` environment `dev` (deploy)

Use **Secrets** only for genuinely sensitive values. Never store AWS access keys, secret access keys, database credentials, JWT secrets, or Terraform state contents in GitHub.

---

## Phase 5A workflow — `terraform-ci.yml`

### Triggers

- Pull requests to `main` (paths: `.github/workflows/terraform-ci.yml`, `bootstrap/**`, `environments/**`, `modules/**`)
- Pushes to `main` (same paths)
- Manual `workflow_dispatch`

### Jobs

| Job | AWS | Approval | Steps |
|-----|-----|----------|-------|
| `fmt` | No | No | `terraform fmt -check -recursive` |
| `validate` | No | No | `terraform init -backend=false`, `terraform validate` |
| `plan-dev` | Yes (OIDC) | No | remote init, `terraform plan` with `TF_BACKEND_IMAGE_TAG` |

### What Phase 5A does not do

- No `terraform apply`
- No saved binary plan file (plans may contain sensitive values even when log output is redacted)
- No plan artifacts uploaded to GitHub
- No Alembic migrations
- No application deployment
- No composite actions
- No protected `dev` environment on the plan job

Plan output appears in the job log only. Saving and applying an exact reviewed plan is reserved for Phase 5B under the protected `dev` environment.

### Concurrency

```yaml
concurrency:
  group: terraform-ci-dev
  cancel-in-progress: true
```

---

## Backend deployment order (Phase 5D — reference only)

Application deployment in `motorclub` will follow this order (not implemented in 5A):

1. Build backend image
2. Tag with immutable Git SHA
3. Push to ECR
4. Read current ECS task definition
5. Register new revision with new image
6. Run one-off ECS task: `alembic upgrade head`
7. Wait for migration task to stop; fail if exit code ≠ 0
8. Update ECS API service to new revision **only after migration success**
9. Wait for service stability
10. Smoke test `/health/ready`

If migration fails, the running service stays on the previous task-definition revision. Alembic does **not** run on API container startup.

---

## Troubleshooting `AssumeRoleWithWebIdentity`

| Symptom | Likely cause |
|---------|----------------|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Role trust `sub` or `aud` does not match the workflow (branch vs environment, or legacy vs ID-qualified `sub`) |
| OIDC fails on `main` with correct role ARN | Trust policy matches `repo:OWNER/REPO:*` but GitHub sends `repo:OWNER@ID/REPO@ID:*` — add both formats |
| Works on `main` but not on PR | Trust policy missing `pull_request` subject or fork PR from untrusted repo |
| `AccessDenied` on S3 state | Role lacks state bucket/key permissions or lockfile object access |
| Plan fails: missing variables | Set all repository variables listed for Phase 5A |
| `use_lockfile` error | Terraform version below 1.10 — use pinned 1.10.5 |
| Init fails: bucket does not exist | Run bootstrap (`bootstrap/`) before first remote plan |

Verify the OIDC token subject in CloudTrail (`AssumeRoleWithWebIdentity` → `userName`) or in the workflow log, and compare to the IAM role trust policy.

---

## Local development

Match CI Terraform version:

```bash
terraform version   # should report 1.10.5
terraform fmt -recursive
cd environments/dev
terraform init -backend=false && terraform validate
```

For remote plan locally, use the same backend config and image tag as CI:

```bash
terraform init -backend-config=backend.hcl
terraform plan -var="backend_image_tag=YOUR_TAG"
```

Operational commands may be documented in the README; GitHub Actions workflows remain the primary CI/CD source of truth.
