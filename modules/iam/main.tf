# ── GKE node pool service account ──────────────────────────────────────────────

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "gke-nodes"
  display_name = "GKE Node Pool"
}

resource "google_project_iam_member" "gke_nodes_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── ESO service account (Secret Manager via Workload Identity) ──────────────────

resource "google_service_account" "eso" {
  project      = var.project_id
  account_id   = "eso-secret-accessor"
  display_name = "External Secrets Operator"
}

resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

# ── cert-manager service account (Cloud DNS DNS-01 via Workload Identity) ────────

resource "google_service_account" "cert_manager" {
  project      = var.project_id
  account_id   = "cert-manager"
  display_name = "cert-manager DNS-01"
}

resource "google_project_iam_member" "cert_manager_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager.email}"
}

# ── Terraform CI service account (used by GitHub Actions nightly teardown) ──────

resource "google_service_account" "terraform_ci" {
  project      = var.project_id
  account_id   = "terraform-ci"
  display_name = "Terraform CI (GitHub Actions)"
}

resource "google_project_iam_member" "terraform_ci_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# roles/editor excludes iam.serviceAccounts.setIamPolicy, which is required to
# destroy google_service_account_iam_member resources (Workload Identity bindings).
resource "google_project_iam_member" "terraform_ci_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# ── Workload Identity Federation for GitHub Actions (no JSON keys in CI) ────────

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"              = "assertion.sub"
    "attribute.repository"        = "assertion.repository"
    "attribute.repository_owner"  = "assertion.repository_owner"
    "attribute.ref"               = "assertion.ref"
  }

  # Only tokens from this GitHub owner's repos can authenticate
  attribute_condition = "attribute.repository_owner == '${var.github_owner}'"
}

resource "google_service_account_iam_member" "terraform_ci_wif" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_owner/${var.github_owner}"
}

# ── helloworld CI service account (image build/push via GitHub Actions) ──────────

resource "google_service_account" "helloworld_ci" {
  project      = var.project_id
  account_id   = "helloworld-ci"
  display_name = "helloworld CI (GitHub Actions)"
}

resource "google_project_iam_member" "helloworld_ci_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.helloworld_ci.email}"
}

resource "google_service_account_iam_member" "helloworld_ci_wif" {
  service_account_id = google_service_account.helloworld_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/platform-helloworld"
}

# ── Kyverno service account (Artifact Registry read for image signature verification) ──

resource "google_service_account" "kyverno_ar" {
  project      = var.project_id
  account_id   = "kyverno-ar"
  display_name = "Kyverno AR Reader (image signature verification)"
}

resource "google_project_iam_member" "kyverno_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.kyverno_ar.email}"
}

resource "google_service_account_iam_member" "kyverno_ar_wi" {
  service_account_id = google_service_account.kyverno_ar.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kyverno/kyverno]"
}
