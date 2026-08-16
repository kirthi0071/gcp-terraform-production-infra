# Production-style GCP Terraform Project

Project: `testing-project-499604` · Region: `asia-south1` · Terraform `~> 1.15.0` · Google provider `~> 7.44.0`

## 1. Architecture

```
Internet
   |
   v
External HTTP(S) Load Balancer (global static IP, health-checked)
   |
   v
Backend Service --> Managed Instance Group (2-6 autoscaled VMs)
   |
   v
Cloud SQL (Postgres, private IP only, no public exposure)
```

```
GitHub                                   GCP
------                                   ---
push/PR --> GitHub Actions --> OIDC token --> Workload Identity Federation
                                                        |
                                                        v
                                          Impersonates GCP Service Account
                                                        |
                                                        v
                                          Terraform (init/plan/apply)
                                                        |
                                              +---------+---------+
                                              |                   |
                                         GCS Remote State   Secret Manager
                                        (qa / prod / pr-N)   (db-password)
```

Root Terraform composes six child modules: `network`, `firewall`,
`service-account`, `vm`, `database`, `load-balancer`. See section 2.

## 2. Design decisions (the "why" behind non-obvious choices)

- **MIG instead of a single VM behind the LB.** A `google_compute_backend_service`
  expects a `group` (instance group / NEG), not a single instance self-link.
  A lone VM also has no self-healing or rolling-update story. So `modules/vm`
  builds an instance template + regional Managed Instance Group + autoscaler,
  which is still "a GCP VM" under the hood, just run as a fleet instead of a
  pet. Full reasoning is in `modules/vm/main.tf`.
- **No public IP on the app VMs.** Only reachable via the LB (for app
  traffic) and via SSH from an explicit CIDR you provide (never
  `0.0.0.0/0` by default).
- **Cloud SQL is private-IP only.** Requires a VPC peering range +
  `google_service_networking_connection` before the instance can attach --
  this is wired explicitly in `modules/database`.
- **Provider config lives only in the root module** (`provider.tf`); child
  modules never declare their own provider block, so they inherit the
  root's and stay reusable across projects/regions. See `provider.tf`.
- **Backend config is partial** (`backend.tf` has no bucket/prefix). The
  real values come from `-backend-config` at `init` time, per environment --
  this is the mechanism that gives qa/prod/each-PR their own isolated state
  without needing separate root modules.
- **Bootstrap is a separate, local-state Terraform config** (`bootstrap/`).
  It creates the state bucket and the WIF pool the main project's CI needs
  before the main project can even run `init`. Circular dependency, solved
  by taking it out of the automated loop entirely -- run once by a human.

## 3. Folder structure

```
terraform-project/
├── versions.tf / provider.tf / backend.tf / variables.tf / locals.tf
├── main.tf / outputs.tf
├── terraform.tfvars.example / .gitignore / .checkov.yaml
├── modules/
│   ├── network/  firewall/  service-account/  vm/  database/  load-balancer/
├── environments/
│   ├── qa/    (terraform.tfvars.example, backend.gcs.tfbackend)
│   └── prod/  (terraform.tfvars.example, backend.gcs.tfbackend)
├── bootstrap/   <- separate config, local state, run once by hand
├── policy/      <- optional OPA/Rego example
└── .github/workflows/ (terraform-qa.yml, terraform-prod.yml)
```

## 4. Prerequisites

- A GCP project (`testing-project-499604`) with billing enabled.
- `gcloud` and `terraform` (1.15.x) installed locally for the one-time
  bootstrap step.
- Required APIs enabled (see below).
- A GitHub repo to hold this code, with permission to add repo Secrets and
  a GitHub Environment.

## 5. Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  secretmanager.googleapis.com \
  iamcredentials.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=testing-project-499604
```

## 6. Bootstrap the state bucket, WIF, and secret container

```bash
cd bootstrap
terraform init
terraform apply \
  -var="project_id=testing-project-499604" \
  -var="region=asia-south1" \
  -var="github_repo=YOUR_GH_ORG/YOUR_GH_REPO"
```

Note the two outputs: `state_bucket_name` and `workload_identity_provider`.

## 7. Secret Manager setup

Bootstrap only creates the **container** `db-password`. Seed the real value
out-of-band, never through Terraform/Git:

```bash
echo -n "A_STRONG_PASSWORD" | \
  gcloud secrets versions add db-password --data-file=- --project=testing-project-499604
```

CI reads it at pipeline time with `gcloud secrets versions access latest`
and exports it as `TF_VAR_db_password` for that one run only (see the
workflows). This is the production-appropriate design: non-sensitive config
stays in Git as plain `.tfvars`, only the sensitive value is fetched live.
An alternative some teams use -- storing an entire `.tfvars` file as one
Secret Manager blob -- is worse: it couples every unrelated config change to
a secret-rotation workflow, and it's all-or-nothing access instead of
scoped-per-value access. If you ever do that as a stopgap, write the file to
disk only inside the ephemeral CI runner and delete it immediately after
use; never commit it.

## 8. WIF setup

Already created by `bootstrap/`. In your GitHub repo, add these **Secrets**
(Settings → Secrets and variables → Actions):

- `WIF_PROVIDER` = the `workload_identity_provider` bootstrap output
- `WIF_SERVICE_ACCOUNT` = the `github_actions_service_account_email` output
- `INFRACOST_API_KEY` = a free key from infracost.io

Add a GitHub **Environment** named `production` (Settings → Environments)
and configure required reviewers -- this is what makes the prod workflow's
`environment: production` actually pause for human approval.

## 9. Local Terraform usage

```bash
terraform init -backend-config=environments/qa/backend.gcs.tfbackend
export TF_VAR_db_password="$(gcloud secrets versions access latest --secret=db-password --project=testing-project-499604)"
terraform plan -var-file=environments/qa/terraform.tfvars.example -var="environment=qa"
terraform apply -var-file=environments/qa/terraform.tfvars.example -var="environment=qa"
```

## 10. QA workflow (per-PR)

Opening a PR runs `terraform-qa.yml`: fmt check → init (state prefix
`ephemeral/pr-<N>`) → validate → plan → Checkov → Infracost comment on the
PR → apply, creating a fully isolated `qa-pr-<N>` environment. Closing the
PR (merged or not) runs the destroy job against that same state prefix, so
nothing lingers.

## 11. Ephemeral PR environment / state isolation

Every PR's resources are named `qa-pr-<N>-...` and live in state prefix
`ephemeral/pr-<N>/` inside the shared state bucket. Two PRs open at once
never touch the same state file, so they can't lock each other out or
overwrite each other's resources -- Terraform's GCS backend takes a lock on
the specific state OBJECT (via a lease), not the whole bucket, so unrelated
prefixes are entirely independent.

## 12. Production workflow

Only triggers on push to `main` (i.e., after PR review + merge). `plan` runs
unattended and uploads the plan as an artifact; `apply` requires the
`production` GitHub Environment's approval gate before it runs the uploaded
plan -- so what gets applied is exactly what was reviewed, not a fresh plan
that could have drifted between approval and apply.

## 13. Terraform state

Remote, in GCS, with Object Versioning enabled (bootstrap enables this) so
a bad apply's state can be rolled back. State is never committed to Git
(`.gitignore` blocks `*.tfstate*`). Locking is automatic and built into the
GCS backend as of recent Terraform/provider versions -- concurrent
`apply`s against the same prefix are serialized safely without any extra
DynamoDB-style lock table (that pattern is AWS-specific; GCS handles it
natively).

## 14. Security

Least-privilege IAM throughout (see `modules/service-account` and
`bootstrap/main.tf` for the exact role lists and justifications), no
service-account JSON keys anywhere (OIDC/WIF only), Secret Manager for the
one sensitive value this project needs, GCS versioning + uniform bucket
access + public-access-prevention on the state bucket, no SSH from
`0.0.0.0/0` by default, dedicated (non-default) service account for the
VMs, and full qa/prod/PR environment separation at both the network and
state layers.

## 15. Cost estimation

Infracost runs on every PR and comments an estimated monthly cost delta.
**Estimated cost is not the actual bill** -- actual spend also depends on
runtime hours actually used, network egress, request volume, storage
consumption over time, any committed-use/sustained-use discounts, and other
consumption-based charges Infracost can't see from static Terraform alone.
Treat it as a sanity check on obviously-oversized changes, not an invoice.

## 16. Destroy procedure

```bash
# QA (or a specific PR's leftover env, replace the prefix/environment):
terraform init -backend-config=environments/qa/backend.gcs.tfbackend
terraform destroy -var-file=environments/qa/terraform.tfvars.example -var="environment=qa"

# Production -- deliberately more friction: flip db_deletion_protection to
# false first if you truly intend to remove Cloud SQL, review the destroy
# plan carefully, and run it through the same approval-gated pipeline
# rather than locally.
```

## 17. Troubleshooting

- **`terraform init` fails with a 403 on the state bucket:** your caller
  identity (local `gcloud auth` or the CI service account) is missing
  `roles/storage.objectAdmin` on the bucket -- check bootstrap's
  `google_project_iam_member.ci_roles`.
- **Cloud SQL creation hangs or fails on `private_network`:** the VPC
  peering (`google_service_networking_connection`) hasn't completed --
  Terraform's `depends_on` in `modules/database` should handle ordering,
  but if you're importing an existing setup, verify the peering exists via
  `gcloud services vpc-peerings list --network=<vpc> --project=<project>`.
- **WIF auth fails in Actions:** double check the `attribute_condition` in
  `bootstrap/main.tf` matches your exact `org/repo`, and that the workflow
  has `permissions: id-token: write`.

---

## Interview questions based on this project

1. Why does the backend service point at an instance group instead of a
   single VM, and what does the MIG's `update_policy` block actually do
   during a rollout?
2. Walk through exactly what happens, step by step, when a GitHub Actions
   job authenticates via WIF instead of a service-account key -- what token
   is exchanged for what, and why is nothing long-lived ever stored as a
   GitHub secret?
3. Why must the GCS state bucket be created outside the main Terraform
   config, and what would go wrong if you tried to have the root module
   create its own backend bucket?
4. The DB password comes from Secret Manager, yet it still ends up in
   Terraform state. Why, and what mitigations does this project apply as a
   result?
5. Explain the difference between what Checkov checks and what an OPA/Rego
   policy like `policy/production_guardrails.rego` checks -- why do you
   need both instead of just one?
6. How does this project prevent two concurrent PRs from corrupting each
   other's Terraform state?
7. Why is `private_ip_google_access` enabled on the subnet even though the
   VMs also don't have public IPs?
8. What's the blast-radius argument for giving the VM a dedicated service
   account instead of the default Compute Engine service account?
9. If you needed to add HTTPS termination at the load balancer, what
   additional resources would you add, and why weren't they included here
   by default?
10. Estimated cost from Infracost came back low, but the actual GCP bill at
    month-end was 3x higher. What are three plausible categories of spend
    Infracost couldn't have predicted?

---

## Production readiness review

Things still needed before this is a *real* production workload, not a
teaching reference:

- **HTTPS/TLS.** Only HTTP (port 80) is wired up. Add a managed SSL
  certificate, a `google_compute_target_https_proxy`, and an HTTP→HTTPS
  redirect URL map -- this needs a real domain name, which this project
  doesn't have yet.
- **Cloud Armor.** No WAF/DDoS policy is attached to the backend service.
  For a public-facing prod app you'd want at least basic rate-limiting and
  known-bad-IP blocking rules.
- **Multi-zone/region resilience beyond the MIG.** The MIG is regional and
  self-heals within `asia-south1`, but there's no cross-region failover;
  Cloud SQL is `ZONAL` availability, not `REGIONAL` (HA) -- flip that for a
  real prod DB, at higher cost.
- **Application-level health check path.** `/healthz` is assumed; the real
  app must implement it, and readiness should reflect DB connectivity, not
  just "process is up".
- **Secret rotation.** Nothing here automates rotating `db-password`; it's
  a manual `gcloud secrets versions add` today.
- **Monitoring/alerting.** IAM roles for log/metric writing exist, but no
  actual alerting policies, uptime checks, or dashboards are defined.
- **Backup/restore drill.** Point-in-time recovery is enabled on Cloud SQL,
  but it's never been tested end-to-end in this project.
- **OPA policy isn't wired into CI yet** -- it's provided as a documented
  example (`policy/`) but the actual `conftest`/`opa eval` step against the
  plan JSON still needs to be added to `terraform-prod.yml` if you want it
  enforced rather than just available.
- **This README's terraform/provider version numbers should be re-verified
  against the Terraform Registry at the time you actually deploy** --
  they were current as of 2026-08-16 but both Terraform and the Google
  provider ship frequently.
