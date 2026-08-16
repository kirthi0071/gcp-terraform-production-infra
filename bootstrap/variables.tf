variable "project_id" {
  type    = string
  default = "testing-project-499604"
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "state_bucket_name" {
  description = "Globally-unique GCS bucket name for Terraform remote state."
  type        = string
  default     = "testing-project-499604-tf-state"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the WIF-mapped service account, in 'org/repo' form."
  type        = string
}

variable "github_service_account_id" {
  type    = string
  default = "github-actions-tf-v2"
}
