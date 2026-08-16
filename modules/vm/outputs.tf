output "instance_group" {
  value       = google_compute_region_instance_group_manager.app.instance_group
  description = "Self-link of the managed instance group -- consumed by the load-balancer module as the backend group."
}

output "mig_name" {
  value = google_compute_region_instance_group_manager.app.name
}

output "instance_template_id" {
  value = google_compute_instance_template.app.id
}

