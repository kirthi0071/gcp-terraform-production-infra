output "lb_ip_address" {
  value       = google_compute_global_address.lb_ip.address
  description = "Public IP of the load balancer. Point your DNS A record here."
}

output "backend_service_id" {
  value = google_compute_backend_service.app.id
}
