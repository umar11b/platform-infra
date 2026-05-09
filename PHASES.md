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
**Status:** In progress

### GKE Cluster (Terraform)
- [ ] Private GKE Standard cluster (private endpoint, private nodes)
- [ ] Control plane authorized networks: Pi public IP only
- [ ] Node pool: e2-small spot instances, min 1 / max 3 nodes
- [ ] Cluster autoscaler enabled
- [ ] Workload Identity enabled on the cluster
- [ ] Network policy enabled (Calico or Dataplane V2)
- [ ] GKE node service account with least-privilege IAM (Artifact Registry reader, logging, monitoring)

### Cluster Lifecycle
- [ ] `make up` — `terraform apply` from Pi, boots cluster
- [ ] `make down` — `terraform destroy`, tears down cluster (preserves GCS state)
- [ ] `make rebuild` — `make down && make up` with timing output
- [ ] Nightly teardown GitHub Actions cron (runs `make down` via Pi SSH or gcloud)
- [ ] Validate: `kubectl get nodes` succeeds from Pi, connection times out from laptop

### Demo Artifact
> Screen recording: `make rebuild` timed end-to-end under 15 minutes. `kubectl get nodes` output from Pi. Connection refused from laptop terminal.

---

## Phase 2 — GitOps Spine
**Milestone:** `kubectl delete` on any Argo-managed resource is reverted within 30 seconds  
**Status:** Not started

### `platform-config` Repo Setup
- [ ] Initialize repo: `apps/`, `infra/`, `overlays/` directory structure
- [ ] Argo CD root Application (app-of-apps pattern)
- [ ] Sub-applications for each add-on (see below)

### Argo CD Bootstrap
- [ ] Argo CD installed immediately after `terraform apply` (one-shot `kubectl apply` or Helm)
- [ ] Argo CD configured to watch `platform-config` repo
- [ ] Argo CD server exposed on internal load balancer or via `kubectl port-forward` for initial setup
- [ ] App-of-apps root application points to `platform-config/apps/`

### Add-on Applications (via Argo CD)
- [ ] **Istio** — base + istiod + ingress gateway via Helm
- [ ] **cert-manager** — via Helm, with CRDs
- [ ] **External Secrets Operator (ESO)** — via Helm
- [ ] **kube-prometheus-stack** — Prometheus + Grafana + Alertmanager via Helm
- [ ] **Kyverno** — via Helm (policies in next phase)

### GitOps Validation
- [ ] All add-on apps show `Synced` + `Healthy` in Argo CD UI
- [ ] Delete a deployment manually → Argo CD reconciles within 30s
- [ ] No manual `kubectl apply` in runbook — all cluster changes go through Git

### Demo Artifact
> Screen recording: `kubectl delete deployment <argocd-managed>`, then Argo CD UI auto-correcting within 30 seconds.

---

## Phase 3 — App End to End
**Milestone:** `curl https://hello.lab.<domain>.com` returns HTTP 200 with a valid TLS cert  
**Status:** Not started

### `helloworld` Service (Go)
- [ ] Go module, `cmd/helloworld/main.go`
- [ ] `GET /healthz` — liveness probe, returns `200 OK`
- [ ] `GET /readyz` — readiness probe, returns `200 OK`
- [ ] `GET /hello` — main endpoint, reads secret from env, returns JSON
- [ ] `GET /metrics` — Prometheus instrumented (request count, latency histogram)
- [ ] Multi-stage Dockerfile, distroless base image
- [ ] Unit tests for each handler

### CI Pipeline (GitHub Actions)
- [ ] `go vet` + `staticcheck` lint step
- [ ] Unit tests (`go test ./...`)
- [ ] Build container image
- [ ] Trivy scan — fail on HIGH/CRITICAL CVEs
- [ ] Generate SBOM with Syft
- [ ] Sign image with cosign (keyless, GitHub Actions OIDC)
- [ ] Push signed image to GCP Artifact Registry
- [ ] Open PR against `platform-config` bumping image tag in Kustomize overlay

### Platform Config (Kustomize)
- [ ] `helloworld` base manifests: Deployment, Service, ServiceAccount, HorizontalPodAutoscaler
- [ ] Kustomize overlay for dev environment
- [ ] `VirtualService` + `Gateway` for Istio ingress routing
- [ ] Resource requests + limits set (required by Kyverno in Phase 4)
- [ ] Non-root user + read-only root filesystem set in securityContext

### TLS (cert-manager + Let's Encrypt + Cloudflare DNS-01)
- [ ] Subdomain `lab.<domain>.com` delegated to Cloudflare
- [ ] Cloudflare API token scoped to zone-edit on that subdomain only
- [ ] Token stored in GCP Secret Manager, pulled by ESO into a Kubernetes Secret
- [ ] cert-manager `ClusterIssuer` for Let's Encrypt production (DNS-01 via Cloudflare)
- [ ] `Certificate` resource for `*.lab.<domain>.com` wildcard
- [ ] Istio ingress gateway configured with TLS cert secret

### Demo Artifact
> `curl -v https://hello.lab.<domain>.com` in terminal showing HTTP 200, TLS handshake details, and valid cert chain.

---

## Phase 4 — Guardrails
**Milestone:** Kyverno blocks an unsigned image deploy on camera  
**Status:** Not started

### Kyverno Policies
- [ ] `disallow-latest-tag` — block images with `:latest` tag
- [ ] `require-resource-limits` — block pods without CPU/memory requests + limits
- [ ] `require-non-root` — block containers running as root (UID 0)
- [ ] `require-readonly-rootfs` — block containers without `readOnlyRootFilesystem: true`
- [ ] `disallow-privileged` — block privileged containers and host-namespace sharing
- [ ] `verify-image-signature` — require cosign keyless signature via Sigstore Fulcio

### Conftest (OPA in CI)
- [ ] OPA policies for manifest validation (pre-merge, in `platform-config` workflow)
- [ ] `kubectl --dry-run=server` against kind cluster in CI
- [ ] Validate policies block what they should (policy unit tests)

### Workload Identity + ESO
- [ ] GCP Service Account for ESO with Secret Manager accessor role
- [ ] Kubernetes ServiceAccount annotated for Workload Identity binding
- [ ] `SecretStore` CR configured (GCP backend, Workload Identity auth)
- [ ] `ExternalSecret` CR for helloworld secret → syncs from Secret Manager to K8s Secret
- [ ] helloworld pod mounts secret as env var (via K8s Secret reference)
- [ ] Validate: secret value readable in app, no JSON key anywhere in the system

### Istio mTLS
- [ ] `PeerAuthentication` set to `STRICT` in helloworld namespace
- [ ] `AuthorizationPolicy` scoping ingress gateway → helloworld traffic only
- [ ] Validate mTLS: `istioctl x authz check` shows ALLOW for legitimate path, DENY for direct pod access

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
| 1     | Cluster up/down     | In progress |
| 2     | GitOps spine        | Not started |
| 3     | App end to end      | Not started |
| 4     | Guardrails          | Not started |
| 5     | Observability       | Not started |
| 6     | Polish              | Not started |
