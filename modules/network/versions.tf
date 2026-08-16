# No provider block here -- provider config lives only in the root module
# (see the root provider.tf explanation). This file documents the provider
# version family the module was written/tested against.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.44.0"
    }
  }
}
