# Resources that already exist in production because they were first created by hand with the
# AWS CLI. Importing them lets Terraform manage them without recreating anything.
# These blocks are safe to keep: once a resource is in state, its import block is a no-op.

import {
  to = module.lambda_api.aws_iam_role_policy.lambda_rekognition
  id = "motorclub-serverless-api-lambda-role:motorclub-serverless-api-lambda-role-rekognition"
}

import {
  to = module.lambda_api.aws_iam_role_policy.lambda_media_invalidation[0]
  id = "motorclub-serverless-api-lambda-role:motorclub-serverless-api-lambda-media-invalidation"
}

import {
  to = module.media_transcode.aws_iam_role_policy.transcode_rekognition
  id = "motorclub-serverless-media-transcode:motorclub-serverless-media-transcode-rekognition"
}

import {
  to = aws_route53_record.resend_dkim[0]
  id = "Z0692558J0GK8WBW8JWY_resend._domainkey.motorclub.co.il_TXT"
}

import {
  to = aws_route53_record.resend_send_mx[0]
  id = "Z0692558J0GK8WBW8JWY_send.motorclub.co.il_MX"
}

import {
  to = aws_route53_record.resend_send_spf[0]
  id = "Z0692558J0GK8WBW8JWY_send.motorclub.co.il_TXT"
}
