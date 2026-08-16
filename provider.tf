# provider.tf
#
# WHY PROVIDER CONFIG LIVES IN THE ROOT MODULE ONLY:
# A Terraform "provider block" configures a plugin connection (which cloud,
# which project, which credentials). Child modules should NEVER declare their
# own provider blocks for two reasons:
#   1. A module that hard-codes its own provider becomes impossible to reuse
#      across projects/regions -- the caller loses control.
#   2. Terraform's provider inheritance model passes the root module's
#      configured provider down into every child module automatically. If a
#      child module also declares a provider block, you get duplicate
#      provider configuration errors or, worse, two different sets of
#      credentials/project scopes fighting each other.
#
# So: root main.tf composes modules -> root provider.tf configures the one
# "google" provider -> every module inherits it implicitly.

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zones[0]
}
