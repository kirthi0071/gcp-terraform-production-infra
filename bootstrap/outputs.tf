output "state_bucket_name" {
  value = google_storage_bucket.tf_state.name
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full resource name -- use as the 'workload_identity_provider' input to google-github-actions/auth."
}

output "github_actions_service_account_email" {
  value = google_service_account.github_actions.email
}
