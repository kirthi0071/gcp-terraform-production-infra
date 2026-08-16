# variables.tf (root module)
#
# Only variables that the ROOT module needs directly, or needs to pass down
# into multiple modules, live here. Module-specific variables live inside
# each module's own variables.tf.

variable "project_id" {
  description = "GCP project ID. For this project: testing-project-499604."
  type        = string
}

variable "region" {
  description = "GCP region. For this project: asia-south1 (Mumbai)."
  type        = string
  default     = "asia-south1"
}

variable "zones" {
  description = "Zones for the regional managed instance group"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment identifier: qa, prod, or qa-pr-<number> for ephemeral PR environments. Every resource name is derived from this."
  type        = string

  validation {
    condition     = can(regex("^(qa|prod|qa-pr-[0-9]+)$", var.environment))
    error_message = "environment must be 'qa', 'prod', or 'qa-pr-<number>'."
  }
}

variable "application_name" {
  description = "Short application name used in resource naming, e.g. 'webapp'."
  type        = string
  default     = "webapp"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the application subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH into VMs. NEVER default this to 0.0.0.0/0. Pass your office/VPN/bastion CIDR explicitly per environment."
  type        = list(string)
}

variable "enable_ssh_from_anywhere" {
  description = "Explicit escape hatch to allow SSH from 0.0.0.0/0. Must be manually set to true; defaults to false. Only ever use for short-lived debugging, never in prod."
  type        = bool
  default     = false
}

variable "machine_type" {
  description = "Compute Engine machine type for the application VM(s)."
  type        = string
  default     = "e2-small"
}

variable "vm_image" {
  description = "Boot image for the application VM."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-1-3840"
}

variable "db_version" {
  description = "Cloud SQL Postgres version."
  type        = string
  default     = "POSTGRES_15"
}

variable "db_disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Whether Cloud SQL instance/database have Terraform + GCP deletion protection enabled. Should be true for prod."
  type        = bool
  default     = true
}

variable "db_password" {
  description = "Application DB user password. In real usage this value is NEVER put in a .tfvars file committed to Git -- it is read from Secret Manager (see modules/database and the Secret Manager section of the README) and injected as a TF_VAR_db_password environment variable at plan/apply time in CI, or via -var on a secured local machine."
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Extra labels merged into local.common_labels."
  type        = map(string)
  default     = {}
}

