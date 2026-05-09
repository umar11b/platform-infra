# Architecture

A production-pattern Kubernetes platform built to mirror how a regulated enterprise runs workloads in the cloud. A Raspberry Pi acts as the only ingress to a private GKE control plane. All cluster state is reconciled from Git via Argo CD. Every deploy passes through a CI pipeline that scans, signs, and policy-checks the artifact before Kyverno admission control gates it at the cluster edge. Workloads authenticate to GCP via Workload Identity, pull secrets from Secret Manager via External Secrets Operator, and communicate over Istio mTLS. Observability is Prometheus + Grafana with a defined SLO and burn-rate alerting. The entire cluster is torn down nightly and rebuilt from Git in under 15 minutes.

---

## Goals

This homelab exists to demonstrate three things credibly to a senior infrastructure engineer or platform recruiter:

1. **DevSecOps.** A pipeline that actually gates deploys on supply-chain checks. Signed images, scanned artifacts, policy enforcement at admission time, secrets that never touch Git.
2. **SRE.** A defined SLO, multi-window burn-rate alerting, a runbook for the alert, and evidence the alert has fired in anger.
3. **Platform engineering.** GitOps as the only deploy path. New workloads onboard via PR. The cluster is ephemeral; Git is the source of truth.

The non-goal is breadth. One workload, one SLO, one policy that actually blocks something — done well, with documentation a senior engineer would respect — beats a sprawl of half-finished components.

---

## Constraints

- **Budget: $0 strict.** Cluster is torn down nightly and rebuilt on demand. GKE control plane runs on the free tier (one zonal cluster per billing account). Compute is e2-small spot nodes during runtime hours only.
- **Hybrid stack.** GCP-native for identity and secrets (Workload Identity, Secret Manager, Artifact Registry). CNCF-portable for everything else (Argo CD, Istio, cert-manager, ESO, Prometheus, Kyverno).
- **Pi 5 as bastion.** The Pi is the only network path with access to the GKE control plane endpoint. No control-plane access from the laptop, ever.

---

## Threat model (v0)

| Asset             | Threat                                                 | Mitigation                                                                                                             |
| ----------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| GKE control plane | Public exposure, credential leak, privilege escalation | Private endpoint; control plane authorized only to Pi public IP; Workload Identity (no JSON keys); IAM least privilege |
| Container images  | Supply-chain attack, vulnerable base                   | CI scans with Trivy, fails on HIGH/CRITICAL; cosign signs every image; Kyverno blocks unsigned images at admission     |
| Cluster manifests | Drift, manual `kubectl apply` bypassing review         | Argo CD is the only writer; cluster is read-only to humans; audit log retained                                         |
| Secrets           | Hardcoding, Git leakage, blast radius                  | Secret Manager is source of truth; ESO pulls at runtime via Workload Identity; no Kubernetes Secrets committed         |
| External traffic  | Plaintext, cert mismanagement, MITM                    | Istio ingress gateway, TLS terminated with cert-manager Let's Encrypt cert, mTLS for east-west                         |
| Bastion (Pi)      | SSH brute force, unpatched OS                          | Key-only SSH, fail2ban, automated `apt upgrade`; Tailscale for personal access (no public SSH from laptop)             |

This list is intentionally incomplete and will grow. A live threat model is the artifact, not a one-time checkbox.

---

## Component decisions

### Cloud platform: GCP

Chosen over AWS because the free tier is friendlier (one GKE control plane is free, $300 credit on signup), Workload Identity is the cleanest identity story in the industry, and the user's target list (Google primary, Microsoft/Amazon secondary) makes GCP fluency a near-direct asset for one of the top targets and a transferable asset for the others.

### Cluster: private GKE Standard, single small node pool

Standard over Autopilot for the learning value — node pools, taints, DaemonSets, and the rest of the CKA surface area are exposed in Standard. Cluster runs spot e2-small nodes (1–3 depending on demo needs) with the control plane on the free tier. Private cluster, private endpoint, control plane authorized to the Pi's public IP only.

### Bastion: Raspberry Pi 5

Sole network path to the cluster control plane. Hosts SSH (key-only), `gcloud`, `kubectl`, `make` targets for cluster lifecycle, and a local checkout of the platform repo. Tailscale (or equivalent) provides personal access from the laptop without exposing SSH publicly.

### IaC: Terraform

State in GCS with versioning and state locking via GCS native locking. Modules: `project-bootstrap`, `network`, `cluster`, `iam`, `dns`. One root module wires them up. `make up` runs `terraform apply`; `make down` runs `terraform destroy`. A nightly GitHub Actions cron runs `make down`.

### GitOps: Argo CD

Bootstrapped immediately after `terraform apply` by a one-line install that points it at the `platform-config` repo. From that moment forward, Argo is the only thing that writes to the cluster. The "app of apps" pattern manages every other add-on: Istio, cert-manager, ESO, Prometheus stack, Kyverno, and the helloworld workload itself.

Argo over Flux because it shows up on more job descriptions, the UI makes the recruiter demo cleaner, and the user's stated preference.

### Service mesh / ingress: Istio

Ingress gateway terminates TLS and routes external traffic. `PeerAuthentication` set to `STRICT` namespace-wide to enforce mTLS for east-west traffic. `AuthorizationPolicy` resources scope which workloads can call which (even when there's only one, the pattern is the artifact).

Istio over a simple ingress controller because the mesh story is the right one for the platform-eng signal, and the user already has working knowledge of it from TD.

### Policy: Kyverno

Admission-time policy enforcement. Initial policy set:

- Disallow `:latest` image tags
- Require resource requests and limits
- Require non-root user, read-only root filesystem
- Require image signature verification (cosign keyless via Sigstore Fulcio)
- Disallow privileged containers and host-namespace sharing

Conftest (OPA in CI) enforces a smaller set of pre-merge policies on the manifest YAML itself. Two policy engines, two enforcement points: shift-left in CI, shift-right at admission.

### Secrets: GCP Secret Manager + External Secrets Operator + Workload Identity

The chain: ESO runs in-cluster, authenticates to GCP using a Kubernetes ServiceAccount bound to a GCP Service Account via Workload Identity, reads from Secret Manager, materializes Kubernetes Secrets in-namespace. The application pod reads them as env vars or mounted files. **Zero JSON service account keys exist anywhere in this system.** That sentence belongs in the README.

### TLS: cert-manager + Let's Encrypt + Cloudflare DNS-01

A subdomain (`lab.yourdomain.com`) is delegated to Cloudflare DNS. cert-manager runs DNS-01 challenges using a scoped Cloudflare API token (zone-edit on that subdomain only). Wildcard cert for `*.lab.yourdomain.com`. HTTP-01 was rejected because mTLS strict mode complicates path-based challenges and DNS-01 supports wildcards.

### Container registry: GCP Artifact Registry

Project-scoped Docker repository. Workload Identity grants the GKE node pool's default service account read access. CI pushes signed images here.

### Observability: Prometheus + Grafana + Alertmanager

Installed via the `kube-prometheus-stack` Helm chart (managed as an Argo Application). One Grafana dashboard for helloworld golden signals (latency, traffic, errors, saturation). One SLO defined as "99% of `/hello` requests under 200ms over 30 days." One multi-window, multi-burn-rate alert (1h fast burn, 6h slow burn) wired to a Discord or Slack webhook.

Dynatrace was rejected on cost. Datadog was rejected for the same reason. The OSS Prometheus stack is what most big tech actually runs internally.

### Workload language: Go

Single binary `helloworld` service with `/healthz`, `/readyz`, `/hello`, and `/metrics` (Prometheus-instrumented) endpoints. Distroless base image. Multi-stage Dockerfile. Reads one secret from env (mounted by ESO).

### CI: GitHub Actions

Per-app workflow:

1. Lint (Go vet, staticcheck) and unit tests
2. Build container image
3. Trivy scan — fail on HIGH/CRITICAL
4. Generate SBOM (Syft)
5. Sign image with cosign (keyless, OIDC from GitHub Actions identity)
6. Push to Artifact Registry
7. Open PR against `platform-config` bumping the image tag

Cluster-config workflow (in the platform-config repo):

1. Conftest validates manifests against OPA policies
2. `kubectl --dry-run=server` against a kind cluster to catch obvious errors
3. Argo CD picks up merge and reconciles

---

## Repository layout

Three repos, each with a deliberate scope:

### `platform-infra`

Terraform for the cloud foundation. Owns: GCP project, VPC, GKE cluster, IAM, Workload Identity Pool, Artifact Registry, Secret Manager seed secrets, Cloudflare DNS records, GCS state bucket. Owns `make up` / `make down` / `make rebuild` and the nightly teardown workflow.

### `platform-config`

The GitOps source of truth. Owns: Argo CD root app-of-apps, sub-apps for every add-on (Istio, cert-manager, ESO, Prometheus stack, Kyverno + policies), the Kustomize overlay for helloworld, environment overlays (dev only, for now). Argo CD watches this repo. **This repo is the cluster.**

### `helloworld`

The workload. Owns: Go source, Dockerfile, GitHub Actions workflows. On merge to main, opens an image-bump PR against `platform-config`.

---

## Build phases

Each phase is independently demonstrable and produces a demo artifact for the eventual portfolio video.

| Phase | Milestone                                                                 | Demo artifact                                                            |
| ----- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 0     | Foundations: Pi hardened, GCP project, Terraform skeleton, billing alerts | `terraform plan` runs clean                                              |
| 1     | Cluster up/down: private GKE via Terraform, nightly teardown cron         | `kubectl get nodes` from Pi works, from laptop fails; rebuild in <15 min |
| 2     | GitOps spine: Argo CD bootstrapped, add-ons installed via app-of-apps     | `kubectl delete` is reverted by Argo within 30s                          |
| 3     | App end to end: helloworld CI pipeline, Argo deploys, public TLS works    | `curl https://hello.lab.yourdomain.com` returns 200 with valid cert      |
| 4     | Guardrails: Kyverno policies, ESO + Workload Identity wired up            | Kyverno blocks an unsigned image deploy on camera                        |
| 5     | Observability: Grafana dashboard, SLO, burn-rate alert                    | Alert fires after deliberate breakage                                    |
| 6     | Polish: README, threat model, demo video, resume bullet                   | Project is interview-ready                                               |

Target pace: eight weeks at evenings + light weekends. Compressible to four with heavier weekend work and Claude Code for boilerplate.

---

## What this project is not

- **Not multi-cluster, multi-region, or multi-tenant.** A real platform handles those; demonstrating the patterns at single-cluster scale is the right target for a portfolio piece.
- **Not a microservice graph.** One workload. The platform mechanics are the interesting part, not the application topology.
- **Not Helm-charted in-house.** Helm is used to install third-party software (Istio, Prometheus stack). The user's own workloads use plain manifests with Kustomize overlays. Authoring a Helm chart for a single app is over-engineering and a known anti-signal.
- **Not always-on.** Spinning up and tearing down a cluster from Git is the discipline being demonstrated. An always-on cluster is cheaper _operationally_ but proves less.

---

## Open questions for v1

- Multi-environment overlay (dev + staging) or stay single-env until v2?
- Add a second workload to demonstrate inter-service `AuthorizationPolicy`, or keep one workload and demonstrate the policy in isolation?
- Move from GitHub Actions to a self-hosted runner on the Pi for the cluster-config workflow (gets the Pi closer to "real platform team" pattern)?
- Backup/restore demo with Velero, or skip until v2?

These are the conversations to have once Phase 5 is done, not before.
