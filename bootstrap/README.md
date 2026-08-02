# Bootstrap — Terraform remote state

One-time setup. Bootstrap uses **local state** stored in this directory.

## Steps

```bash
cd bootstrap
terraform init
terraform apply -var='state_bucket_name=motorclub-terraform-state-YOUR_ACCOUNT_ID'
```

Copy the `backend_config_example` output into `../environments/dev/backend.hcl` (and prod when ready).

Do not commit `backend.hcl` if it contains account-specific values — use `backend.hcl.example` as a template.
