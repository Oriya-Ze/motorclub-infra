# GitHub Actions in the motorclub app repo deploys production on every push to main:
# tests, Lambda images to ECR, the Neon migration, the Lambda code, then the frontend.
# It authenticates with OIDC, so there are no long-lived AWS keys in GitHub.
#
# The ARNs below are written out rather than taken from the edge/storage/lambda modules, so a
# targeted apply of this file never drags in unrelated pending changes from those modules.

locals {
  github_app_repo    = "Oriya-Ze/motorclub"
  github_app_repo_id = "Oriya-Ze@189972747/motorclub@1316075917"

  deploy_lambda_arns = [
    "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:motorclub-serverless-api",
    "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:motorclub-serverless-media-transcode",
  ]
  deploy_frontend_bucket_arn = "arn:aws:s3:::motorclub-serverless-frontend"
  deploy_frontend_cdn_arn    = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/ESGAYJYZ7492K"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "ci"
  }
}

data "aws_iam_policy_document" "github_deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs that run in the production GitHub Environment. GitHub may send the subject
    # with or without the owner and repository IDs.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_app_repo}:environment:production",
        "repo:${local.github_app_repo_id}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.project_name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_trust.json
  max_session_duration = 3600

  tags = {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "ci"
  }
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushLambdaImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      aws_ecr_repository.api.arn,
      aws_ecr_repository.media_transcode.arn,
    ]
  }

  # Code only. The role cannot change environment variables, IAM, or any other function.
  statement {
    sid = "UpdateLambdaCode"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
    ]
    resources = local.deploy_lambda_arns
  }

  statement {
    sid       = "ListFrontendBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.deploy_frontend_bucket_arn]
  }

  statement {
    sid       = "UploadFrontend"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.deploy_frontend_bucket_arn}/*"]
  }

  statement {
    sid       = "InvalidateFrontend"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [local.deploy_frontend_cdn_arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.project_name}-github-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

output "github_deploy_role_arn" {
  description = "Role the motorclub GitHub Actions deploy workflows assume"
  value       = aws_iam_role.github_deploy.arn
}
