# ---------------------------------------------------------------------------
# 1. Remote state bucket
# ---------------------------------------------------------------------------
# - uniform_bucket_level_access: turns off legacy per-object ACLs, forcing
#   all access through IAM -- the modern, auditable way to control access.
# - versioning: REQUIRED for state safety. If a bad apply corrupts state,
#   you can restore the previous object version. Without this, a corrupted
#   or overwritten state file is unrecoverable.
# - lifecycle_rule: keeps the bucket from growing forever while still
#   retaining enough history to roll back.
# - public_access_prevention: belt-and-braces against ever making state
#   world-readable (state can contain sensitive values -- see database
#   module notes).
resource "google_storage_bucket" "tf_state" {
  project                     = var.project_id
  name                        = var.state_bucket_name
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 20
    }
    action {
      type = "Delete"
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Workload Identity Federation for GitHub Actions (no JSON keys)
# ---------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name               = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restrict to only tokens whose repository claim matches this repo -- this
  # is what prevents *any* GitHub Actions workflow anywhere from using this
  # pool; only workflows running inside var.github_repo can mint a token
  # this pool will accept.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = var.github_service_account_id
  display_name = "GitHub Actions Terraform runner"
}

# Bind the WIF identity (scoped to this exact GitHub repo) to be allowed to
# impersonate the service account. This -- not a downloaded key file -- is
# the credential GitHub Actions actually uses.
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Minimum roles the CI service account needs to plan/apply this project.
# NOT Owner/Editor -- scoped to exactly the resource types this project
# manages, plus state bucket access and Secret Manager read access.
locals {
  ci_roles = [
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/compute.instanceAdmin.v1",
    "roles/compute.loadBalancerAdmin",
    "roles/cloudsql.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor",
    "roles/servicenetworking.networksAdmin",
    "roles/storage.objectAdmin", # for the state bucket
  ]
}

resource "google_project_iam_member" "ci_roles" {
  for_each = toset(local.ci_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.github_actions.email}"
}

# ---------------------------------------------------------------------------
# 3. Secret Manager containers (values are seeded out-of-band, see README)
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "db-password"

  replication {
    auto {}
  }
}
