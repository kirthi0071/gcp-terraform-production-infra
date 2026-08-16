terraform {
  required_version = "~> 1.15.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.44.0"
    }
  }
  # Deliberately NO backend block -- this config uses local state on purpose.
  # It is run rarely, by a human, and is small enough that local state (kept
  # safe, e.g. in a password manager or a private, access-controlled repo)
  # is an acceptable, well-known exception to "always use remote state".
}

provider "google" {
  project = var.project_id
  region  = var.region
}
