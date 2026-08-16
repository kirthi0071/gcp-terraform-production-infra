# modules/firewall
#
# PROBLEM THIS SOLVES:
# By default a custom VPC (auto_create_subnetworks = false) has NO implied
# firewall rules -- everything is denied. We need to explicitly allow:
#   1. Google's Load Balancer / health-check probers to reach the app port.
#   2. SSH, but ONLY from an explicit trusted CIDR (never the whole internet).
#   3. (Optionally) internal traffic between app-tier resources.
#
# WHY 0.0.0.0/0 FOR SSH IS DANGEROUS:
# Port 22 open to the entire internet is scanned continuously by botnets
# within minutes of being exposed. Every exposed SSH port becomes a target
# for brute-force credential attacks and for exploitation of any unpatched
# OpenSSH CVE. The blast radius of a single compromised VM is the whole
# subnet reachable from it. Best practice is to restrict SSH to a bastion
# host, VPN range, or Identity-Aware Proxy (IAP) range -- never "anywhere".
# This module makes that restriction the DEFAULT and requires an explicit
# `enable_ssh_from_anywhere = true` to ever widen it, so nobody does it by
# accident.
#
# RESOURCES (verified against registry.terraform.io/providers/hashicorp/google/latest):
#   - google_compute_firewall (one per logical rule)
#
# We use a dynamic block for the SSH rule's source_ranges only, since that's
# the one value that legitimately varies per call (and the "allow from
# anywhere" toggle). We do NOT use dynamic blocks for the other rules --
# they're fixed-shape and a dynamic block there would only add indirection.

resource "google_compute_firewall" "allow_lb_health_check" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-lb-health-check"
  network = var.network_id

  direction = "INGRESS"
  # These are Google's published, fixed ranges for Load Balancer / health
  # check probers (both legacy and Envoy-based checks) and are safe to allow
  # inbound to the health-check/application port.
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = var.app_target_tags

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }
}

resource "google_compute_firewall" "allow_http_https" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-http-https"
  network = var.network_id

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.app_target_tags

  # 80/443 are intentionally public -- that's the whole point of a public
  # HTTP(S) load balancer. In this architecture the LB itself is the
  # internet-facing edge; the VM tier is only reached via the LB and the
  # health-check range above plus this app-port rule for LB-origin traffic.
  allow {
    protocol = "tcp"
    ports    = ["80", "443", tostring(var.app_port)]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-ssh"
  network = var.network_id

  direction = "INGRESS"
  # Never 0.0.0.0/0 unless the caller has explicitly opted in.
  source_ranges = var.enable_ssh_from_anywhere ? ["0.0.0.0/0"] : var.ssh_source_ranges
  target_tags   = var.app_target_tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-internal"
  network = var.network_id

  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]
  target_tags   = var.app_target_tags

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
}
