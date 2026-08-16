# versions.tf
#
# WHY THIS FILE EXISTS ON ITS OWN:
# Separating version constraints from provider configuration makes it obvious,
# at a glance, exactly which Terraform core version and which provider
# versions this codebase was written and tested against. Reviewers and CI
# pipelines check this file first.
#
# Verified against the Terraform Registry on 2026-08-16:
#   - Terraform core latest stable: 1.15.8
#   - hashicorp/google latest stable: 7.44.0
#
# We pin with "~>" (pessimistic constraint operator). "~> 1.15.0" allows
# patch releases (1.15.1, 1.15.2, ...) but blocks 1.16.0+. This gives you
# bug fixes automatically while preventing an unreviewed minor/major upgrade
# from silently changing provider behavior mid-pipeline.

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.44.0"
    }
  }
}
