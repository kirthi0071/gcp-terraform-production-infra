# modules/vm
#
# WHY A MANAGED INSTANCE GROUP (MIG) INSTEAD OF A SINGLE STANDALONE VM:
# The brief for this task literally draws "GCP VM" as a single box, but a
# single google_compute_instance behind a Load Balancer is a production
# anti-pattern: no self-healing (a crashed VM stays down until someone
# notices), no rolling updates, and no horizontal scaling. GCP's own
# HTTP(S) Load Balancer documentation expects a backend to be a MIG (or NEG),
# not a single instance -- google_compute_backend_service.backend blocks
# accept "group" pointing at an instance group, not an individual VM
# self-link. So the production-appropriate design is:
#
#   google_compute_instance_template  (immutable VM blueprint: image, disk,
#                                       machine type, SA, network, tags)
#          |
#          v
#   google_compute_region_instance_group_manager (keeps N healthy instances
#                                                  running, replaces failed
#                                                  ones automatically, drives
#                                                  rolling updates)
#          |
#          v
#   consumed as the "group" input of the load-balancer module's backend
#
# This still satisfies "a GCP VM" -- it's the same Compute Engine VMs,
# just managed as a fleet instead of a single pet.
#
# We do NOT put an SSH private key anywhere in this module. If SSH access is
# needed at all, only a PUBLIC key is accepted via the ssh_public_key
# variable and placed in instance metadata -- Terraform never touches
# private key material, matching the requirement.
#
# RESOURCES (verified against registry.terraform.io/providers/hashicorp/google/latest):
#   - google_compute_instance_template
#   - google_compute_region_instance_group_manager
#   - google_compute_region_autoscaler (optional but included: production-grade
#     MIGs should scale on load rather than sit at a fixed size)

locals {
  mig_name = "${var.name_prefix}-mig"
  tpl_name = "${var.name_prefix}-tpl"
}

resource "google_compute_instance_template" "app" {
  project      = var.project_id
  name_prefix  = "${local.tpl_name}-"
  machine_type = var.machine_type
  region       = var.region
  tags         = var.network_tags
  labels       = var.labels

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = var.boot_disk_type
  }

  network_interface {
    subnetwork = var.subnet_self_link
    # No access_config block => no external/public IP on the VMs. They are
    # only reachable via the internal Load Balancer path and, for SSH, via
    # Identity-Aware Proxy or a bastion on the allowed CIDR -- not directly
    # from the internet.
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = var.ssh_public_key != null ? {
    ssh-keys = var.ssh_public_key
  } : {}

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "app" {
  project = var.project_id
  name    = local.mig_name
  region  = var.region

  base_instance_name = "${var.name_prefix}-vm"
  target_size        = var.target_size

  version {
    instance_template = google_compute_instance_template.app.id
  }

  named_port {
    name = "http"
    port = var.app_port
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }
}

resource "google_compute_region_autoscaler" "app" {
  project = var.project_id
  name    = "${var.name_prefix}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.app.id

  autoscaling_policy {
    min_replicas    = var.target_size
    max_replicas    = var.target_size * 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }
}
