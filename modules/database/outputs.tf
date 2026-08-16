output "instance_connection_name" {
  value       = google_sql_database_instance.this.connection_name
  description = "Used by the Cloud SQL Auth Proxy / app connection string."
}

output "private_ip_address" {
  value = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  value = google_sql_database.app.name
}
