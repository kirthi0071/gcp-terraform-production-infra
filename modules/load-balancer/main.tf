# modules/load-balancer
#
# This builds a global external HTTP Load Balancer (classic external ALB
# architecture). NOTE: this module provisions the HTTP path end-to-end and
# working. For HTTPS you additionally need a google_compute_managed_ssl_certificate
# (or a certificate manager cert) and a google_compute_target_https_proxy in
# front of a reserved static IP + DNS record pointed at it -- left as a
# documented next step in the README rather than guessed at here, since it
# requires a real domain name this project doesn't have.
#
# CHAIN OF RESOURCES (this is the exact GCP external HTTP(S) LB object
# graph -- verified against registry.terraform.io/providers/hashicorp/google/latest):
#
#   google_compute_global_address        (reserved static external IP)
#            |
#   google_compute_health_check          (HTTP health check against app_port)
#            |
#   google_compute_backend_service       (points at the MIG, uses the health check)
#            |
#   google_compute_url_map               (routes all paths to the one backend service)
#            |
#   google_compute_target_http_proxy     (binds the url map to HTTP)
#            |
#   google_compute_global_forwarding_rule (binds the static IP + port 80 to the proxy)
#
# The backend attaches to the MIG's instance_group output from the vm
# module -- this is exactly the "managed instance group as backend" pattern
# GCP's own HTTP(S) LB documentation recommends over pointing at a single VM.

resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "${var.name_prefix}-lb-ip"
}

resource "google_compute_health_check" "app" {
  project             = var.project_id
  name                = "${var.name_prefix}-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.app_port
    request_path = "/healthz"
  }
}

resource "google_compute_backend_service" "app" {
  project               = var.project_id
  name                  = "${var.name_prefix}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.app.id]

  backend {
    group           = var.backend_instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "app" {
  project         = var.project_id
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  project = var.project_id
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_forwarding_rule" "app" {
  project               = var.project_id
  name                  = "${var.name_prefix}-fwd-rule"
  target                = google_compute_target_http_proxy.app.id
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
