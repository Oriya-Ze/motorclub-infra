locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  enable_google_oauth  = var.google_client_id != "" && var.google_client_secret != ""
  oauth_callback_urls  = distinct(concat(var.oauth_callback_urls, var.extra_oauth_callback_urls))
  oauth_logout_urls    = distinct(concat(var.oauth_logout_urls, var.extra_oauth_logout_urls))
  common_tags = merge(var.tags, {
    Project     = "MotorClub"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "cognito"
  })
}

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  dynamic "email_configuration" {
    for_each = var.enable_ses_email ? [1] : []
    content {
      email_sending_account = "DEVELOPER"
      source_arn            = aws_ses_domain_identity.main[0].arn
      from_email_address    = var.from_email_address
    }
  }

  dynamic "email_configuration" {
    for_each = var.enable_ses_email ? [] : [1]
    content {
      email_sending_account = "COGNITO_DEFAULT"
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                     = "preferred_username"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  # Kept for Cognito compatibility (schema attributes cannot be removed once added).
  schema {
    name                     = "phone_number"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 0
      max_length = 20
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-users"
  })
}

resource "aws_cognito_user_pool_domain" "main" {
  count        = local.enable_google_oauth ? 1 : 0
  domain       = var.cognito_domain_prefix != "" ? var.cognito_domain_prefix : local.name_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_identity_provider" "google" {
  count = local.enable_google_oauth ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "email openid profile"
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
  }

  attribute_mapping = {
    email              = "email"
    name               = "name"
    preferred_username = "email"
    username           = "sub"
  }
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "${local.name_prefix}-api-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  supported_identity_providers  = local.enable_google_oauth ? ["COGNITO", "Google"] : ["COGNITO"]

  callback_urls = local.enable_google_oauth ? local.oauth_callback_urls : null
  logout_urls   = local.enable_google_oauth ? local.oauth_logout_urls : null

  allowed_oauth_flows_user_pool_client = local.enable_google_oauth
  allowed_oauth_flows                  = local.enable_google_oauth ? ["code"] : []
  allowed_oauth_scopes                 = local.enable_google_oauth ? ["openid", "email", "profile"] : []

  read_attributes = [
    "email",
    "name",
    "preferred_username",
  ]

  write_attributes = [
    "email",
    "name",
    "preferred_username",
  ]

  depends_on = [aws_cognito_identity_provider.google]
}
