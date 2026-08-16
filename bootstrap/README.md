# Bootstrap

This is a SEPARATE, tiny Terraform config from the main project. It exists to
solve a chicken-and-egg problem: the main project's `backend.tf` needs a GCS
bucket to already exist before `terraform init` can use it as a backend, and
the WIF pool/provider that GitHub Actions authenticates through needs to
exist before any CI-driven `terraform apply` can run at all.

You CANNOT have the main project's own Terraform state depend on a bucket
that the main project itself creates -- that's a circular dependency
(chicken needs the egg, egg needs the chicken). The standard, HashiCorp-
recommended pattern is: bootstrap this handful of one-time resources with
**local state** (run once, by a human, from a workstation with the right
permissions), then never touch it again with automation.

## What this creates
1. The GCS bucket used as the remote state backend for qa/prod/ephemeral.
2. The Workload Identity Pool + Provider + IAM binding GitHub Actions uses
   to authenticate (no long-lived JSON keys).
3. The Secret Manager secret CONTAINERS (not values) that the main project
   expects to already exist (e.g. `db-password`). You add the actual secret
   VALUE afterwards with `gcloud secrets versions add`, so the value is
   never in Terraform state or Git.

## Usage (run once, manually, by a human with sufficient IAM)
```bash
cd bootstrap
terraform init
terraform apply \
  -var="project_id=testing-project-499604" \
  -var="region=asia-south1" \
  -var="github_repo=YOUR_GH_ORG/YOUR_GH_REPO"

# Then seed the real secret value out-of-band, e.g.:
echo -n "REPLACE_WITH_A_STRONG_PASSWORD" | \
  gcloud secrets versions add db-password --data-file=- --project=testing-project-499604
```

After this, the bucket name and WIF provider resource name it prints out go
into `environments/*/backend.gcs.tfbackend` and into the GitHub Actions
workflow's `workload_identity_provider` input, respectively.
