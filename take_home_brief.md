# Take-Home Exercise — DevOps & Cloud Intern at Aleph

## Overview

You'll design the infrastructure-as-code, Kubernetes setup, and CI/CD pipeline for deploying a small notification engine to **Azure Kubernetes Service (AKS)**. The system has two parts — an API for intake and a worker that processes the queue. We provide both; your job is to make them deployable, scalable, and operationally sound.

This is the kind of work you'd actually do in the first month at Aleph, so treat it as a preview of the real thing.

## Time budget

Plan for **30-35 hours of focused work spread over 8-9 calendar days**. We want a thoughtful, well-organized submission — not a sprint. Quality over quantity. If something is incomplete because you ran out of time, say so in the README — that's better than hand-waved code.

## What we're testing

- How you structure Terraform code (modules, state, secrets, multi-environment)
- How you think about Kubernetes deployment (probes, limits, secrets, scaling, multi-workload coordination)
- How you design CI/CD pipelines (security, gating, secret handling, release flows)
- How you reason about identity and access (no static credentials, anywhere)
- How you handle distributed task systems (queue-based async processing)
- How you document your decisions so a teammate can pick up where you left off

We are **not** testing whether you picked the same choices we'd have picked. We're testing whether you can defend the choices you made.

## Stack

| Layer | Technology |
|---|---|
| Cloud | Azure |
| Orchestration | AKS (Azure Kubernetes Service) |
| IaC | Terraform |
| CI/CD | GitHub Actions |
| Application | Python + FastAPI + asyncpg (provided in `starter_app/`) |
| Database | Azure Database for PostgreSQL Flexible Server |
| Secrets | Azure Key Vault |
| Registry | Azure Container Registry (ACR) |
| Queue | Azure Storage Queue **or** Azure Service Bus (your choice — justify it) |

---

## The starter app

The `starter_app/` directory contains a working two-process notification engine:

**API process** (`uvicorn app.main:app`):
- `POST /notify` — Accepts `{channel, recipient, message}`, persists to Postgres, publishes to the queue, returns the notification with status `queued`
- `GET /notify/{id}` — Fetches a notification by id
- `GET /health` — Liveness probe
- `GET /ready` — Readiness probe (checks DB connectivity)
- `GET /metrics` — Prometheus-format metrics

**Worker process** (`python -m app.worker`):
- Consumes messages from the queue, simulates sending the notification, updates the status to `sent` in Postgres
- Long-lived process; designed to be deployed as its own Kubernetes Deployment

The app uses a queue abstraction (`app/queue_client.py`) with three backends: `memory` (local dev only), `storage` (Azure Storage Queue), `servicebus` (Azure Service Bus). You pick one of the Azure backends for deployment and configure via env var `QUEUE_BACKEND`. **You don't need to modify the queue client code.**

Configuration is read entirely from environment variables — see `starter_app/README.md` for the full list.

---

## What you build

### Hard requirements

#### Terraform

- Resource group containing all resources
- AKS cluster (2-node system pool minimum, managed identity, RBAC enabled, workload identity enabled)
- Azure Container Registry **attached to AKS** for image pulls — no static credentials anywhere
- Azure Database for PostgreSQL Flexible Server with private networking
- **Queue:** Azure Storage Queue **or** Azure Service Bus — provisioned with identity-based access (no shared access signatures committed)
- Key Vault for application secrets
- Virtual network with appropriate subnets for AKS and Postgres
- State backend configured in Azure Storage (describe the bootstrap step in your README)
- Code organized in **modules** — no resources defined inline in the root
- **Multi-environment: `dev` and `prod`** — separate state, separate config. Workspaces, directory structure, or `tfvars` strategy — your call, but justify it. Both environments should be deployable from the same codebase with no copy-paste.

#### Kubernetes

You're deploying **two workloads** — the API and the worker — sharing the same image but running different commands.

- **Deployment** for the API (replicas, labels, image from ACR)
- **Deployment** for the worker (separate scaling, command `python -m app.worker`)
- Service (ClusterIP) for the API
- Ingress for external access — pick NGINX ingress controller or AKS app routing add-on, justify your choice
- ConfigMap for non-secret configuration
- Secret backed by Key Vault — CSI Secret Store driver **or** Workload Identity (your choice, justify it)
- **Liveness and readiness probes** at the right endpoints (the worker has no HTTP server — design something appropriate)
- **Resource requests and limits** defined for both workloads
- **HorizontalPodAutoscaler** for the API on CPU. Worker HPA on queue depth is a stretch goal — see below.

#### CI/CD (GitHub Actions)

- **PR workflow:**
  - `terraform fmt`, `terraform validate`, `terraform plan` (per environment)
  - Manifest validation (`kubeconform` or equivalent)
  - **Application tests:** run the `pytest` suite included in the starter, and **add at least one additional test of your own** for an endpoint or behavior of your choice. Submissions that don't run tests in CI fail this dimension.
- **Main-branch deploy workflow** (push to `main` → deploys to **dev**):
  - Build and push container to ACR
  - `terraform apply` with an approval gate
  - `kubectl apply` / Helm upgrade
- **Release workflow** (push of a `v*.*.*` tag → deploys to **prod**):
  - Build container with the tag as image version
  - Promote to prod with explicit approval
  - The tag is the artifact of record
- **Azure authentication via OIDC federated credentials** — no long-lived service principal secrets
- Reasonable failure handling and clear logs

#### Database migrations

The starter app currently does `CREATE TABLE IF NOT EXISTS` on startup. That's fine for the take-home but won't survive a real schema change. **Pick a migration approach and implement it** — Alembic, sqitch, a dedicated K8s Job, init container, or anything else you'd defend in production. Wire it into your CI/CD pipeline or document why you've left it manual. Justify your choice in the decision log.

#### Documentation

A `README.md` at the repo root containing:

- **Architecture overview** — text or Mermaid diagram. Include both the API/worker/queue shape and the multi-env deploy flow.
- **Application integration contract** — how would an *internal Aleph service* (not an end user) publish a notification to your engine? What's the API contract, how does it authenticate, what's the SLA, what happens if the queue is down or the DB is unreachable? A future Aleph service should be able to integrate against your docs without reading your code.
- **Local development instructions** — how to run locally
- **Deployment instructions** — what someone reproducing your setup would need to do, including the state-backend bootstrap
- **Decision log** — 6-8 of your major choices, each with a 1-2 paragraph explanation. Include: queue backend, secrets approach, migration strategy, multi-env structure, ingress controller, identity model.
- **Cost analysis** — run your deployed design through the Azure pricing calculator. State the estimated monthly cost for dev and prod environments. State what you'd cut first to save 30%. 100 words is enough.
- **Known limitations** — what's not done and what you'd add given more time

---

### Stretch goals

Try **two or three** — please don't attempt all. We want depth, not breadth.

- **★ Deploy to your own Azure subscription** (free trial works — $200 credit). Include screenshots or a short Loom showing the API responding AND the worker actually processing notifications end-to-end. Include any cost-control measures you put in place. **This is the highlighted bonus.**
- **KEDA-based queue-depth autoscaling for the worker** — scale workers based on backlog instead of CPU. Maps directly to how distributed task systems are scaled in production.
- Network policies restricting pod-to-pod and pod-to-database traffic
- Helm chart instead of raw manifests, with per-environment values
- Application Insights integration with a custom dashboard query
- `cert-manager` + Let's Encrypt for TLS termination via ingress
- Pod security: read-only root filesystem, dropped capabilities, security context constraints (non-root is already enforced in the starter)

---

## Submission

Submit a **public GitHub repository link** by email to `sushant@aleph.tech`.

The repo should contain:

- All Terraform code (multi-env structure), K8s manifests, GitHub Actions workflows
- Modified app code (only if your design needed it)
- README, decision log, integration contract, cost analysis
- Screenshots or demo link if you attempted the deploy bonus
- Commit history that shows progressive work — please don't squash everything into one final commit

**Deadline:** [DATE] (9 calendar days from receipt of this brief)

---

## What happens next

We'll review the submission. If it passes our bar, we'll schedule a **45-60 minute technical round** where you walk us through your architecture and design choices. Expect questions like *"what would you do if the queue filled up,"* *"why this and not that,"* *"how does your worker scale relative to your API,"* and *"what would you change about your own design now that you've finished it."*

---

## Practical notes

- **Don't commit secrets** — no `.env` files, no `kubeconfig`, no service principal credentials. We'll check.
- If you deploy to your own subscription, **set a budget alert at $20-30**. AKS control plane is ~$0.10/hr; node VMs, queue, and Postgres add a bit more. Tear down when done.
- If anything is ambiguous, **make a defensible choice and document it** in your decision log. We won't clarify mid-exercise.
- AI tools are fair game for boilerplate, but we'll spot heavily-generated code you can't defend in the technical round. Use as a tool, not a replacement.

---

## A note on tone

This is a real piece of work, not a test of trivia. We've tried to scope it so it's challenging but achievable, and so it reflects what your actual first month would look like. If you have questions after starting, you can email us — we'd rather you ask than guess wrong on something fundamental. Good luck.

— Sushant Garud
CTO, Aleph Technologies
