# policy/production_guardrails.rego
#
# OPTIONAL OPA (Open Policy Agent) policy example, evaluated against a
# `terraform show -json tfplan` plan export in CI (a `conftest test` or
# `opa eval` step you can add to terraform-prod.yml if/when you want this
# layer). Not wired into the workflow by default -- see README for why.
#
# WHY THIS EXISTS SEPARATELY FROM TERRAFORM VARIABLE VALIDATION AND CHECKOV:
#   - Terraform `validation {}` blocks (see variables.tf) check a SINGLE
#     variable's shape in isolation, at plan time, with no knowledge of the
#     rest of the plan. Good for "is this string one of qa/prod/qa-pr-N".
#   - Checkov scans the Terraform SOURCE CODE against a large library of
#     pre-built, general-purpose cloud security rules. It doesn't know your
#     org's specific business rules (e.g. "prod may only run in
#     asia-south1").
#   - OPA/Rego (or HashiCorp Sentinel, the closed-source equivalent used in
#     Terraform Cloud/Enterprise) evaluates the PLAN JSON -- the fully
#     resolved set of resources Terraform is about to create/change --
#     against POLICY YOU WRITE. This is where org-specific rules belong:
#     "production resources must carry an environment label", "only these
#     machine types are approved for prod", "prod must stay in
#     asia-south1". It runs after plan (so it sees real, resolved values)
#     but before apply (so a violation blocks the run).
#
# Summary of where each tool fits:
#   variable validation -> single-input shape checks, at plan time
#   Checkov              -> general cloud security best practices, on source
#   OPA / Sentinel        -> custom, org-specific business policy, on the plan

package terraform.production

import future.keywords.in

deny[msg] {
    input.resource_changes[i].type == "google_compute_region_instance_group_manager"
    change := input.resource_changes[i].change.after
    not change.region == "asia-south1"
    msg := sprintf("Production compute resources must be in asia-south1, got %v", [change.region])
}

deny[msg] {
    input.resource_changes[i].type == "google_compute_firewall"
    change := input.resource_changes[i].change.after
    some allow in change.allow
    "22" in allow.ports
    "0.0.0.0/0" in change.source_ranges
    msg := "SSH firewall rules must not allow 0.0.0.0/0"
}
