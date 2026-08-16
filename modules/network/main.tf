# modules/network
#
# PROBLEM THIS SOLVES:
# Every environment needs its own isolated VPC + subnet so that QA traffic
# can never accidentally reach a prod VM at the network layer, and so
# destroying an ephemeral PR environment cleanly tears down its own network
# without touching anyone else's.
#
# WHY IT'S A MODULE:
# The exact same set of resources is needed for qa, prod, and every
# qa-pr-<n> environment. Instead of copy-pasting this block repeatedly, we
# parameterize it once.
#
# RESOURCES (verified against registry.terraform.io/providers/hashicorp/google/latest):
#   - google_compute_network        (custom, non-default VPC; auto_create_subnetworks = false)
#   - google_compute_subnetwork     (custom subnet in var.region)
#
# We do NOT use the GCP default VPC (auto-mode, un-reviewed firewall rules) --
# the task explicitly requires a custom VPC, and it's bad practice beyond a
# throwaway sandbox.

locals {
  vpc_name    = "${var.name_prefix}-vpc"
  subnet_name = "${var.name_prefix}-subnet"
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = local.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project       = var.project_id
  name          = local.subnet_name
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  # Lets a VM with no external IP still reach Google APIs (Secret Manager,
  # Cloud SQL Admin API, etc.) over Google's private backbone.
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
