output "network_id" {
  value       = google_compute_network.this.id
  description = "Self-link/ID of the VPC. Consumed by the firewall module."
}

output "network_name" {
  value = google_compute_network.this.name
}

output "subnet_id" {
  value       = google_compute_subnetwork.this.id
  description = "Self-link/ID of the subnet. Consumed by the VM module."
}

output "subnet_name" {
  value = google_compute_subnetwork.this.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.this.self_link
}
