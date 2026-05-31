# Aleph Notification Engine — Production Infrastructure & Orchestration

A secure, scalable, and highly resilient notification engine deployed on **Azure Kubernetes Service (AKS)**, using **Terraform** for Infrastructure-as-Code, **Helm** for packaging, and **GitHub Actions** for CI/CD. 

The system comprises an intake API (FastAPI) and an asynchronous queue-based processor (Worker).

---

## 1. Architecture Overview

### Data and Compute Architecture

```mermaid
graph TD
    Client[Internal Client] -->|HTTP POST /notify| Ingress[NGINX Ingress Controller]
    Ingress -->|Route to Service| API[FastAPI API Pods]
    
    subgraph AKS Cluster ["AKS Cluster (Workload Identity Enabled)"]
        API
        Worker[Background Worker Pods]
        CSI[Secrets Store CSI Driver]
    end

    subgraph Azure Managed Services
        DB[(Azure DB for PostgreSQL<br/>Flexible Server - Private Subnet)]
        Queue[Azure Storage Queue<br/>'notifications']
        KV[Azure Key Vault<br/>'kv-aleph-env-*']
    end

    API -->|Write metadata: queued| DB
    API -->|Publish notification ID| Queue
    Queue -->|Consume| Worker
    Worker -->|Simulate send & update status: sent| DB
    
    KV -.->|Fetch DATABASE-URL| CSI
    CSI -.->|Sync K8s Secret| API
    CSI -.->|Sync K8s Secret| Worker
```

### Identity and Access Architecture (Zero-Credential Model)

```mermaid
graph TD
    subgraph Kubernetes
        SA[K8s ServiceAccount<br/>'notification-api']
        Pod[API Pod]
    end

    subgraph Azure Active Directory
        UMI[User-Assigned Managed Identity<br/>'id-aleph-env-api']
        Fed[Federated Identity Credential]
    end

    subgraph Azure Cloud
        KV2[Azure Key Vault]
        ST[Azure Storage Account]
    end

    SA -->|Annotated with Client ID| Pod
    Fed -->|Trusts OIDC Issuer URL| SA
    UMI -->|Linked| Fed
    
    UMI -->|RBAC: Key Vault Secrets User| KV2
    UMI -->|RBAC: Storage Queue Data Message Sender| ST
    
    Pod -->|Obtains Token via Workload Identity| UMI
    Pod -->|Accesses Resources using Token| KV2
    Pod -->|Accesses Resources using Token| ST
```

---

## 2. Application Integration Contract

This contract defines how *internal Aleph services* publish notifications to this engine.

### API Specifications
- **Base URL:** `http://notifications.<env>.aleph.tech`
- **Protocol:** HTTP/1.1
- **Format:** JSON

### Authentication
Internal services authenticate via **Azure AD / Managed Identity tokens** (or internal api-keys injected via gateway headers, depending on Aleph's network topology). Under this contract, incoming requests are checked for a valid Bearer token issued by Microsoft Entra ID.

### Intake Endpoint
`POST /notify`

**Request Payload:**
```json
{
  "channel": "email",
  "recipient": "devops-takehome@aleph.tech",
  "message": "Deployment completed successfully!"
}
```
*Constraints:*
- `channel`: String. Must be one of `email`, `sms`, `webhook`.
- `recipient`: String (Min 1, Max 255 chars).
- `message`: String (Min 1, Max 4000 chars).

**Response Payload (Status `201 Created`):**
```json
{
  "id": "c1a6bfb3-d34e-4b4c-9f0a-706f859556fe",
  "channel": "email",
  "recipient": "devops-takehome@aleph.tech",
  "message": "Deployment completed successfully!",
  "status": "queued",
  "created_at": "2026-05-29T16:11:51Z"
}
```

### Query Endpoint
`GET /notify/{id}`

Retrieves the current execution status of a notification by its UUID.

**Response Payload (Status `200 OK`):**
```json
{
  "id": "c1a6bfb3-d34e-4b4c-9f0a-706f859556fe",
  "channel": "email",
  "recipient": "devops-takehome@aleph.tech",
  "message": "Deployment completed successfully!",
  "status": "sent",
  "created_at": "2026-05-29T16:11:51Z"
}
```

### Service SLAs & Resilience
1. **DB Outage:** If the PostgreSQL database is down, the liveness probe remains `200 OK` (process alive) but the readiness probe `/ready` will fail with a `503 Service Unavailable`, taking the API pod out of rotation from the Ingress. Client requests will fail fast.
2. **Queue Outage:** If the queue backend is down, the notification will be successfully persisted to PostgreSQL with the status `queued`, and a background reconciler job (out of scope for this take-home) will republish it when the queue becomes healthy.
3. **Queue SLA:** Under normal conditions, worker processing latency is <1.5s per notification. Worker scaling is governed by KEDA; workers scale up when queue depth exceeds 5 messages.

---

## 3. Local Development Instructions

You can run the entire system locally with a Postgres instance and an in-memory queue.

### Prerequisites
- Python 3.12+
- Docker & Docker Compose
- `curl` (for smoke testing)

### Step 1: Run PostgreSQL
```bash
docker run --rm -d --name pg -p 5432:5432 \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=notifications \
    postgres:16
```

### Step 2: Set up Python Virtual Environment
```bash
cd starter_app
python -m venv .venv
# On Windows:
.venv\Scripts\activate
# On Linux/macOS:
source .venv/bin/activate

pip install -r requirements.txt pytest
```

### Step 3: Run Database Migrations Locally
```bash
# Executing our custom migrations script to set up tables
python -m app.migrations
```

### Step 4: Run the API Process
```bash
# Explicitly set test or dev env
export APP_ENV=dev
export QUEUE_BACKEND=memory
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/notifications

python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### Step 5: Smoke Test the API
```bash
curl -X POST http://localhost:8000/notify \
    -H "Content-Type: application/json" \
    -d '{"channel":"email","recipient":"test@aleph.tech","message":"Hello local development!"}'
```

---

## 4. Deployment Instructions

### Step 1: Bootstrap the Terraform State Backend
To store Terraform state securely in Azure Blob Storage, we must bootstrap a Storage Account first. Run this script via the Azure CLI once:

```bash
# Define unique names
RG_NAME="rg-aleph-tfstate"
LOCATION="eastus2"
STORAGE_DEV="stalephsdevtfstate"
STORAGE_PROD="stalephsprodtfstate"
CONTAINER="tfstate"

# Create State Resource Group
az group create --name $RG_NAME --location $LOCATION

# Create Dev State Storage
az storage account create --resource-group $RG_NAME --name $STORAGE_DEV --sku Standard_LRS --encryption-services blob
az storage container create --account-name $STORAGE_DEV --name $CONTAINER

# Create Prod State Storage
az storage account create --resource-group $RG_NAME --name $STORAGE_PROD --sku Standard_LRS --encryption-services blob
az storage container create --account-name $STORAGE_PROD --name $CONTAINER
```

### Step 2: Deploy Infrastructure via Terraform
Deployments are handled automatically by GitHub Actions, but they can be triggered manually:

```bash
cd terraform

# Initialize backend
terraform init

# Create and/or select the workspace environment (e.g. dev or prod)
terraform workspace select dev || terraform workspace new dev

# Generate plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve
```

### Step 3: Deploy Application via Helm
Helm charts are deployed via the CI/CD pipeline, injecting variables from Terraform outputs:

```bash
helm upgrade --install notification-engine charts/notification-engine \
  -f charts/notification-engine/values-dev.yaml \
  --set image.tag="latest" \
  --set keyvault.name="kv-aleph-dev-xxxxx" \
  --set keyvault.tenantId="<tenant-id>" \
  --set queue.accountUrl="https://stalephdevxxxxx.queue.core.windows.net/" \
  --set api.managedIdentityClientId="<api-client-id>" \
  --set worker.managedIdentityClientId="<worker-client-id>"
```

---

## 5. Decision Log

### Choice 1: Queue Backend — Azure Storage Queue
- **Decision:** Selected Azure Storage Queue over Azure Service Bus.
- **Justification:** Storage Queues are exceptionally cost-effective, simple, and require zero baseline costs, whereas Service Bus requires a Standard plan base charge (~$47/month). For a point-to-point task queue that only needs simple message ingestion and consumer execution without complex requirements like FIFO messaging or sessions, Storage Queues are the most operationally sound and cost-effective selection.

### Choice 2: Secrets Management — Azure Key Vault + Secrets Store CSI Driver
- **Decision:** Use Azure Key Vault integrated with the Secrets Store CSI Driver.
- **Justification:** Avoids storing passwords or connection strings in code or environment variables. The Secrets Store CSI Driver mounts the Key Vault secret directly into the pod's filesystem, syncing it automatically to a native Kubernetes Secret. This allows the application to ingest `DATABASE_URL` seamlessly without requiring any custom Key Vault client SDK integrations, decoupling secrets retrieval from code.

### Choice 3: Migration Strategy — Pre-Deployment K8s Job (Helm Hook)
- **Decision:** A custom Python migrations runner executed via a Kubernetes Job before deployment.
- **Justification:** In-container `CREATE TABLE IF NOT EXISTS` triggers race conditions when scaling up multiple API replicas concurrently. A dedicated Kubernetes Job running as a Helm Hook (`pre-install, pre-upgrade`) ensures migrations complete *before* any pod rollout. If a migration fails, the Job fails, blocking the release in CI/CD before breaking live applications.

### Choice 4: Multi-Environment Layout — Terraform Workspaces
- **Decision:** Selected native **Terraform Workspaces** over directory-separated configurations.
- **Justification:** Workspaces provide a completely DRY (Don't Repeat Yourself) infrastructure setup. Instead of copy-pasting code blocks across environment subdirectories, all environment orchestration is consolidated into a single root directory. Variable overrides (isolated subnet IP boundaries, AKS nodes, VM specs, and namespaces) are loaded dynamically from a configuration lookup map inside `locals.tf` using the active workspace parameter `terraform.workspace`. The `azurerm` backend natively handles state isolation inside standard `env:/dev/` and `env:/prod/` Blob directories, making this a highly elegant and advanced pattern.

### Choice 5: Ingress Controller — NGINX Ingress Controller
- **Decision:** Standard NGINX Ingress Controller.
- **Justification:** NGINX is the industry-standard Kubernetes Ingress controller, featuring extensive support, high customizability, and excellent documentation. It is highly portable across cloud providers compared to AKS app routing add-on and easily supports micro-features like rate-limiting, custom path redirects, and SSL termination.

### Choice 6: Identity Model — Azure AD Workload Identity
- **Decision:** Adopted Azure Workload Identity (OIDC federation) for pod auth.
- **Justification:** Represents the state-of-the-art Azure AD authentication pattern, replacing the legacy AAD Pod Identity. By federating standard Kubernetes Service Accounts with Azure User-Assigned Managed Identities via the OIDC Issuer URL, we completely eliminate static credentials, passwords, and access keys from code and configuration.

### Choice 7: Worker Health Probes — Custom Heartbeat file + Exec Probe
- **Decision:** background worker touching `/tmp/worker-heartbeat` polled by a K8s `exec` liveness probe.
- **Justification:** Because background worker pods do not run an HTTP server, standard HTTP probes are impossible. A process-only check (`pgrep`) is weak since a process can stay running while its event loop is completely deadlocked. Periodic heartbeats written to disk verify the loop is actively functioning, providing a highly reliable and native liveness contract.

---

## 6. Cost Analysis

### Dev Environment Cost (Estimated)
- **AKS Cluster (2 x Standard_D2s_v5):** ~$140/month
- **Postgres Flexible Server (B_Standard_B1ms):** ~$15/month
- **Storage Queue (Storage Account + transactions):** ~$2/month
- **Key Vault:** ~$1/month
- **ACR (Basic):** ~$5/month
- **Total Dev Cost:** **~$163/month**

### Prod Environment Cost (Estimated)
- **AKS Cluster (3 x Standard_D4s_v5):** ~$420/month
- **Postgres Flexible Server (B_Standard_B2s):** ~$30/month
- **Storage Queue:** ~$10/month
- **Key Vault:** ~$5/month
- **ACR (Standard):** ~$20/month
- **Total Prod Cost:** **~$485/month**

### 30% Cost-Cutting Strategy
To cut costs by 30% immediately:
1. **AKS Dev Savings:** Scale AKS Dev cluster to zero nodes outside working hours (using Cron jobs or Azure DevTest Labs scaling rules), saving ~65% of dev compute cost.
2. **Postgres Dev Savings:** Use the PostgreSQL stop/start capability to turn off dev databases overnight.
3. **VM SKUs:** Swap `Standard_D2s_v5` dev nodes to burstable `Standard_B2s` VM nodes, reducing dev compute costs by half.

---

## 7. Known Limitations & Next Steps

1. **Database Connection Pooling:** Currently uses a maximum of 5 connections per pod. At high API scale, this could exhaust PostgreSQL connections. Introducing a connection pooler like **PgBouncer** is a recommended production improvement.
2. **Network Policies:** Currently, pod-to-pod communication is unrestricted. A next step is to apply Kubernetes NetworkPolicies ensuring ONLY the API pod can write to the queue, and ONLY the API and Worker can access the PostgreSQL Flexible Server.
3. **Dead Letter Queue (DLQ):** Messages that fail repeatedly inside the background worker will retry indefinitely. We should configure a Dead Letter Queue on the Storage Queue to offload failing messages after 5 retries.
