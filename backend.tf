# backend.tf
#
# We use a GCS backend for remote state. Two important design choices:
#
# 1. NO credentials are ever written here. GCS backend authentication is
#    handled by Application Default Credentials (ADC) -- in CI that means the
#    short-lived token minted by Workload Identity Federation (see the
#    GitHub Actions workflows). Writing a key file path or embedding a
#    service-account key in this file would defeat the entire point of using
#    OIDC/WIF and would be a credential leak risk the moment this file is
#    committed to Git.
#
# 2. This is a PARTIAL backend configuration -- notice "bucket" and "prefix"
#    are NOT hard-coded here. That's intentional: QA, Production, and every
#    ephemeral PR environment must use different state prefixes inside the
#    same (or different) state bucket, and Terraform does not allow variables
#    inside a backend block. The actual bucket/prefix values are supplied at
#    `terraform init` time via -backend-config flags (see environments/*.gcs.tfbackend
#    files, and the CI workflows). This lets one codebase safely drive many
#    isolated states.

terraform {
  backend "gcs" {
    # Supplied via: terraform init -backend-config="bucket=..." -backend-config="prefix=..."
    # or: terraform init -backend-config=environments/qa/backend.gcs.tfbackend
  }
}
