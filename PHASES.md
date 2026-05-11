# Build Phases

Tracks implementation progress across all phases of the homelab platform. Each phase is independently demonstrable. See ARCHITECTURE.md for full context on every decision.

---

## Phase 0 — Foundations
**Milestone:** `terraform plan` runs clean  
**Status:** Complete ✓ — 34 resources, 0 errors

### Pi Hardening (manual)
- [ ] Install Raspberry Pi OS (64-bit, headless)
- [ ] Create non-root user, disable root login
- [ ] SSH key-only authentication (disable password auth)
- [ ] Install and configure fail2ban (SSH jail)
- [ ] Install Tailscale (personal access from laptop — no public SSH)
- [ ] Enable unattended-upgrades for automated `apt upgrade`
- [ ] Install `gcloud`, `kubectl`, `terraform`, `make`, `cosign`
- [ ] Clone `platform-infra` repo to Pi

### GCP Bootstrap (Terraform)
- [ ] Create GCP project (or import existing)
- [ ] Enable required APIs: container.googleapis.com, secretmanager, artifactregistry, iam, dns, cloudresourcemanager, compute
- [ ] Create GCS bucket for Terraform state (versioning + native locking)
- [ ] Configure billing alerts (budget at $5 — should never fire, confirms assumptions)
- [ ] Create Artifact Registry Docker repository

### Terraform Skeleton (`platform-infra` repo)
- [ ] Initialize repo with `.gitignore`, `README.md`, `Makefile`
- [ ] Root module wiring all child modules
- [ ] `modules/project-bootstrap` — APIs, billing alerts
- [ ] `modules/network` — VPC, subnets, Cloud NAT, firewall rules
- [ ] `modules/cluster` — private GKE Standard, e2-small spot node pool
- [ ] `modules/iam` — service accounts, Workload Identity Pool, IAM bindings
- [ ] `modules/dns` — Cloud DNS zone, Cloudflare delegation records
- [ ] `Makefile` targets: `up`, `down`, `rebuild`, `plan`
- [ ] GCS backend config with state locking
- [ ] GitHub Actions workflow: nightly `make down` cron

### Demo Artifact
> `terraform plan` runs clean with no errors and no unintended resource diffs.

---

## Phase 1 — Cluster Up/Down
**Milestone:** `kubectl get nodes` from Pi works; from laptop fails; rebuild from scratch in <15 min  
**Status:** Complete ✓ — 3 nodes Ready, cluster up in 641s

### GKE Cluster (Terraform)
- [x] Private GKE Standard cluster (private endpoint, private nodes)
- [x] Control plane authorized networks: Pi public IP only
- [x] Node pool: e2-small spot instances, min 1 / max 3 nodes
- [x] Cluster autoscaler enabled
- [x] Workload Identity enabled on the cluster
- [x] Network policy enabled (Dataplane V2 / ADVANCED_DATAPATH)
- [x] GKE node service account with least-privilege IAM (Artifact Registry reader, logging, monitoring)

### Cluster Lifecycle
- [x] `make up` — `terraform apply` from Pi, boots cluster
- [x] `make down` — `terraform destroy`, tears down cluster (preserves GCS state)
- [x] `make rebuild` — `make down && make up` with timing output
- [ ] Nightly teardown GitHub Actions cron — workflow exists; verify WIF_PROVIDER and TERRAFORM_SA_EMAIL secrets are set in GitHub repo
- [x] Validate: `kubectl get nodes` succeeds from Pi (3 nodes Ready); Pi-only authorized networks block laptop access

### Demo Artifact
> Screen recording: `make rebuild` timed end-to-end under 15 minutes. `kubectl get nodes` output from Pi. Connection refused from laptop terminal.

---

## Phase 2 — GitOps Spine
**Milestone:** `kubectl delete` on any Argo-managed resource is reverted within 30 seconds  
**Status:** Complete ✓ — all add-ons Healthy/Synced; deletion reconciled in 2s

### `platform-config` Repo Setup
- [x] Initialize repo: `apps/`, `infra/`, `overlays/` directory structure
- [x] Argo CD root Application (app-of-apps pattern)
- [x] Sub-applications for each add-on (see below)

### Argo CD Bootstrap
- [x] Argo CD installed immediately after `terraform apply` (one-shot `kubectl apply` via `make bootstrap`)
- [x] Argo CD configured to watch `platform-config` repo (root.yaml points to github.com/umar11b/platform-config)
- [x] Argo CD server accessible via `kubectl port-forward` — printed by `make bootstrap`
- [x] App-of-apps root application points to `platform-config/apps/`

### Add-on Applications (via Argo CD)
- [x] **Istio** — base + istiod + ingress gateway via Helm (sync-wave ordered: 1, 2, 3)
- [x] **cert-manager** — via Helm, with CRDs
- [x] **External Secrets Operator (ESO)** — via Helm
- [x] **kube-prometheus-stack** — Prometheus + Grafana + Alertmanager via Helm
- [x] **Kyverno** — via Helm (policies in next phase)

### GitOps Validation
- [x] All add-on apps show `Synced` + `Healthy` in Argo CD UI
- [x] Delete a deployment manually → Argo CD reconciles within 30s (actual: 2s)
- [x] No manual `kubectl apply` in runbook — all cluster changes go through Git

### Demo Artifact
> Screen recording: `kubectl delete deployment <argocd-managed>`, then Argo CD UI auto-correcting within 30 seconds.

---

## Phase 3 — App End to End
**Milestone:** `curl https://hello.lab.umarzaman.ca` returns HTTP 200 with a valid TLS cert  
**Status:** Complete ✓ — `curl https://hello.lab.umarzaman.ca/hello` returns HTTP 200, TLS 1.3, Let's Encrypt wildcard cert

### `helloworld` Service (Go)
- [x] Go module, `cmd/helloworld/main.go`
- [x] `GET /healthz` — liveness probe, returns `200 OK`
- [x] `GET /readyz` — readiness probe, returns `200 OK`
- [x] `GET /hello` — main endpoint, reads secret from env, returns JSON
- [x] `GET /metrics` — Prometheus instrumented (request count, latency histogram)
- [x] Multi-stage Dockerfile, distroless base image
- [x] Unit tests for each handler

### CI Pipeline (GitHub Actions)
- [x] `go vet` + `staticcheck` lint step
- [x] Unit tests (`go test ./...`)
- [x] Build container image
- [x] Trivy scan — fail on HIGH/CRITICAL CVEs
- [x] Generate SBOM with Syft
- [x] Sign image with cosign (keyless, GitHub Actions OIDC)
- [x] Push signed image to GCP Artifact Registry
- [x] Open PR against `platform-config` bumping image tag in Kustomize overlay

### Platform Config (Kustomize)
- [x] `helloworld` base manifests: Deployment, Service, ServiceAccount, HorizontalPodAutoscaler
- [x] Kustomize overlay for dev environment
- [x] `VirtualService` + `Gateway` for Istio ingress routing
- [x] Resource requests + limits set (required by Kyverno in Phase 4)
- [x] Non-root user + read-only root filesystem set in securityContext

### TLS (cert-manager + Let's Encrypt + Cloud DNS DNS-01)
- [x] Subdomain `lab.umarzaman.ca` delegated to Cloud DNS via NS records at GoDaddy
- [x] cert-manager GCP service account with `dns.admin`, bound via Workload Identity
- [x] helloworld secret stored in GCP Secret Manager, pulled by ESO into K8s Secret
- [x] cert-manager `ClusterIssuer` for Let's Encrypt production (DNS-01 via Cloud DNS)
- [x] `Certificate` resource for `*.lab.umarzaman.ca` wildcard — issued and Ready
- [x] Istio ingress gateway configured with TLS cert secret

### Demo Artifact
> `curl -v https://hello.lab.umarzaman.ca/hello` — HTTP 200, TLS 1.3, cert issuer: Let's Encrypt R12, subject: `*.lab.umarzaman.ca`

---

## Phase 4 — Guardrails
**Milestone:** Kyverno blocks an unsigned image deploy on camera  
**Status:** Complete ✓ — all policies enforced; mTLS validated; unsigned image blocked on camera

### Kyverno Policies
- [x] `disallow-latest-tag` — block images with `:latest` tag
- [x] `require-resource-limits` — block pods without CPU/memory requests + limits
- [x] `require-non-root` — block containers running as root (UID 0)
- [x] `require-readonly-rootfs` — block containers without `readOnlyRootFilesystem: true`
- [x] `disallow-privileged` — block privileged containers and host-namespace sharing
- [x] `verify-image-signature` — require cosign keyless signature via Sigstore Fulcio

### Conftest (OPA in CI)
- [x] OPA policies for manifest validation (pre-merge, in `platform-config` workflow)
- [x] `kubectl --dry-run=server` against kind cluster in CI
- [x] Validate policies block what they should (policy unit tests)

### Workload Identity + ESO
- [x] GCP Service Account for ESO with Secret Manager accessor role
- [x] Kubernetes ServiceAccount annotated for Workload Identity binding
- [x] `SecretStore` CR configured (GCP backend, Workload Identity auth)
- [x] `ExternalSecret` CR for helloworld secret → syncs from Secret Manager to K8s Secret
- [x] helloworld pod mounts secret as env var (via K8s Secret reference)
- [x] Validate: secret value readable in app, no JSON key anywhere in the system

### Istio mTLS
- [x] `PeerAuthentication` set to `STRICT` in helloworld namespace
- [x] `AuthorizationPolicy` scoping ingress gateway → helloworld traffic only
- [x] Validate mTLS: `istioctl x authz check` shows ALLOW for ingress gateway; plain-text from non-mesh pod returns connection reset (curl exit 56)

### Demo Artifact
> Screen recording: attempt to deploy a pod with an unsigned image → Kyverno admission webhook returns deny with policy name. Then attempt with `:latest` tag → second deny.

---

## Phase 5 — Observability
**Milestone:** Burn-rate alert fires after deliberate breakage  
**Status:** Not started

### Grafana Dashboard
- [ ] Dashboard provisioned via ConfigMap (GitOps — not manually created in UI)
- [ ] Golden signals panels: request rate, error rate, p50/p95/p99 latency, pod saturation
- [ ] Dashboard JSON stored in `platform-config` repo

### SLO Definition
- [ ] SLO: 99% of `/hello` requests complete under 200ms over a 30-day window
- [ ] SLI implemented as Prometheus recording rule (ratio of fast requests)
- [ ] Error budget recording rules (30d, 1h, 6h windows)

### Alerting
- [ ] Multi-window, multi-burn-rate alert:
  - Fast burn: >14× error rate over 1h window
  - Slow burn: >6× error rate over 6h window
- [ ] Alertmanager route → Discord or Slack webhook
- [ ] Runbook linked from alert annotations (Markdown file in repo)

### Alert Validation
- [ ] Deliberate breakage: deploy a version that returns 500s or is artificially slow
- [ ] Confirm alert fires in Alertmanager and notification arrives in Discord/Slack
- [ ] Restore healthy version and confirm alert resolves

### Demo Artifact
> Screen recording: Grafana dashboard with golden signals, then deliberate 500-error injection, alert firing in Alertmanager, notification appearing in Discord/Slack.

---

## Phase 6 — Polish
**Milestone:** Project is interview-ready  
**Status:** Not started

### Documentation
- [ ] `platform-infra` README: architecture diagram, prerequisites, `make up/down` walkthrough
- [ ] `platform-config` README: repo structure, how to onboard a new workload (PR-based)
- [ ] `helloworld` README: local dev, CI pipeline walkthrough, how the secret gets there
- [ ] Live threat model (update ARCHITECTURE.md threat table with v1 mitigations)
- [ ] Runbook for burn-rate alert (linked from Alertmanager)

### Resume + Portfolio
- [ ] Resume bullet drafted (quantified: rebuild time, SLO %, policy enforcement)
- [ ] Demo video (5–7 min): covers each phase milestone artifact
- [ ] GitHub repos set to public with clean commit history

### Open Questions to Resolve (post Phase 5)
- Multi-environment overlay (dev + staging) or stay single-env until v2?
- Second workload to demo inter-service `AuthorizationPolicy`, or keep one?
- Self-hosted GitHub Actions runner on Pi for cluster-config workflow?
- Velero backup/restore demo, or skip to v2?

---

## Progress Summary

| Phase | Description         | Status      |
|-------|---------------------|-------------|
| 0     | Foundations         | Complete ✓  |
| 1     | Cluster up/down     | Complete ✓  |
| 2     | GitOps spine        | Complete ✓  |
| 3     | App end to end      | Complete ✓  |
| 4     | Guardrails          | Complete ✓  |
| 5     | Observability       | Not started |
| 6     | Polish              | Not started |
