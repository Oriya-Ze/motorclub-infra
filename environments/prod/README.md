# Production environment

Scaffold only. Do **not** apply until dev is validated.

Copy `environments/dev/` as a starting point and adjust:

- `environment = "prod"`
- `multi_az = true` (database module)
- `deletion_protection = true`
- `enable_waf = true`
- `allow_broad_media_cors_in_dev = false`
- Separate remote state key: `prod/terraform.tfstate`

Custom domains for production should be enabled only after the DNS migration procedure in the root README.
