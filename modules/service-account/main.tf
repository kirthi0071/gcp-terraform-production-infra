# modules/service-account
#
# PROBLEM THIS SOLVES:
# The application VM needs to call GCP APIs (read a DB password from Secret
# Manager, write logs/metrics) as itself, not as a human's identity and not
# as the shared Compute Engine default service account.
#
# WHY NOT THE DEFAULT COMPUTE SERVICE ACCOUNT:
# The GCE default service account (PROJECT_NUMBER-compute@developer.gserviceaccount.com)
# historically gets broad "Editor" access on many projects, is shared across
# every VM in the project, and can't be scoped per-workload. If one VM is
# compromised, an attacker inherits whatever that shared identity can do
# project-wide. A dedicated per-workload service account with only the roles
# that workload actually needs limits blast radius to exactly this app.
#
# IAM ROLES GRANTED AND WHY (least privilege -- no Owner, no Editor):
#   - roles/secretmanager.secretAccessor
#       Lets the VM read the DB password secret VERSION it needs at boot/
#       runtime. Does NOT allow creating, listing, or modifying secrets.
#   - roles/cloudsql.client
#       Lets the VM open an authorized connection to the Cloud SQL instance
#       (via the Cloud SQL Auth Proxy / private IP), without granting any
#       Cloud SQL admin capability (no ability to create/delete instances,
#       change flags, etc).
#   - roles/logging.logWriter, roles/monitoring.metricWriter
#       Lets the VM ship its own logs/metrics to Cloud Logging/Monitoring --
#       standard, narrow, write-only roles.
#
# RESOURCES (verified against registry.terraform.io/providers/hashicorp/google/latest):
#   - google_service_account
#   - google_project_iam_member (one per role, not a single broad grant)

resource "google_service_account" "vm_sa" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-vm-sa"
  display_name = "Dedicated VM service account for ${var.name_prefix}"
}

locals {
  minimal_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
  all_roles = toset(concat(local.minimal_roles, var.extra_roles))
}

resource "google_project_iam_member" "vm_sa_roles" {
  for_each = local.all_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}
