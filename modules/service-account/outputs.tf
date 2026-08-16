output "email" {
  value       = google_service_account.vm_sa.email
  description = "Email of the dedicated VM service account. Consumed by the vm module."
}

output "id" {
  value = google_service_account.vm_sa.id
}
