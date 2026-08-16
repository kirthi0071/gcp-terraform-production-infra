# modules/database
#
# Postgres on Cloud SQL, reachable ONLY over private IP inside our VPC --
# never a public IP -- per the requirement to not expose the database
# publicly.
#
# PRIVATE CONNECTIVITY MECHANICS:
# Cloud SQL private IP is not "just another host in your subnet" -- it lives
# in a separate Google-managed network that gets VPC-peered to yours. That
# peering requires a reserved, allocated IP range (google_compute_global_address
# with purpose = VPC_PEERING) and an active
# google_service_networking_connection before the SQL instance can attach to
# your network. This is the single most common Cloud SQL Terraform mistake --
# forgetting the peering means `private_network` on the instance fails or
# hangs. We wire that dependency explicitly below.
#
# TERRAFORM VARIABLE vs SECRET MANAGER vs TERRAFORM STATE -- WHY IT MATTERS:
#   - A Terraform VARIABLE (var.db_password) is just an input value at plan/
#     apply time. If you put the literal password in a .tfvars file, that
#     file itself becomes the secret and is at risk the moment it's copied,
#     logged, or committed.
#   - SECRET MANAGER is the actual system of record for the secret's value.
#     In this project, the plan is: the real password never lives in a
#     tfvars file at all. CI reads it out of Secret Manager at pipeline run
#     time and exports it as the TF_VAR_db_password environment variable,
#     which Terraform then uses to populate var.db_password for exactly one
#     run. Nothing about that flow writes the password to disk in Git.
#   - TERRAFORM STATE, however, will still contain the password in plaintext
#     inside the `google_sql_user` resource's attributes, because Terraform
#     has to know the value to be able to detect drift. This is true
#     regardless of where the value originally came from. That's exactly why
#     the state bucket itself must be locked down (see section 26 / README):
#     encrypted at rest (GCS defaults to this), versioned, and IAM-restricted
#     to the small set of identities that legitimately need state access.
#
# RESOURCES (verified against registry.terraform.io/providers/hashicorp/google/latest):
#   - google_compute_global_address (VPC peering range reservation)
#   - google_service_networking_connection (the actual peering)
#   - google_sql_database_instance (Postgres, private IP only, backups on)
#   - google_sql_database
#   - google_sql_user

resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "${var.name_prefix}-sql-peering-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                  = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = "${var.name_prefix}-sql"
  region              = var.region
  database_version    = var.db_version
  deletion_protection = var.deletion_protection

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.tier
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled    = false # no public IP -- private connectivity only
      private_network = var.network_id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "02:00"
    }

    user_labels = var.labels
  }
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = var.app_db_name
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "app" {
  project  = var.project_id
  name     = var.app_db_user
  instance = google_sql_database_instance.this.name
  password = var.db_password
}
