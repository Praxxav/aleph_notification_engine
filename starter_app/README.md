# Notification Engine (Starter App)

A two-process notification engine for the Aleph DevOps & Cloud Intern take-home: an **API** that accepts notification requests and publishes them to a queue, and a **worker** that consumes the queue and marks notifications as `sent`.

**You don't need to modify this app — your job is to deploy it.** You may modify it if your design requires it; document any changes in your top-level README.

## Architecture

```
   client ──HTTP──▶ API ──┬─▶ Postgres (status: queued)
                          └─▶ Queue ──▶ Worker ──▶ Postgres (status: sent)
```

The API and worker run from the **same container image** but are invoked with different commands. This is intentional — your Kubernetes Deployments will share the image and differ only in `command`/`args`.

## Components

### API (`uvicorn app.main:app`)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/notify` | Create a notification. Body: `{channel, recipient, message}`. Persists to DB, publishes to queue, returns `201` with the record (status `queued`). |
| `GET` | `/notify/{id}` | Fetch a notification by id. |
| `GET` | `/health` | **Liveness probe.** Returns 200 if the process is up. |
| `GET` | `/ready` | **Readiness probe.** Returns 200 only if the database is reachable. |
| `GET` | `/metrics` | Prometheus-format metrics. |

### Worker (`python -m app.worker`)

Long-running process. Consumes messages from the queue, simulates a brief send (random 0.2-1.0s sleep), and updates the notification row to `status: sent`. No HTTP server — you'll need a non-HTTP approach to probes (think about it).

### Queue client (`app/queue_client.py`)

Three backends, selected via `QUEUE_BACKEND` env var:

- `memory` — In-process only. For unit tests and quick smoke runs. Doesn't work across processes.
- `storage` — Azure Storage Queue. Requires `STORAGE_QUEUE_ACCOUNT_URL` and `STORAGE_QUEUE_NAME`.
- `servicebus` — Azure Service Bus. Requires `SERVICEBUS_NAMESPACE` and `SERVICEBUS_QUEUE_NAME`.

Both Azure backends use `DefaultAzureCredential`, which means **no connection strings or shared access keys**. Workload Identity, Managed Identity, the Azure CLI (local), or env-var credentials all work.

## Configuration

The app reads configuration exclusively from environment variables:

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `DATABASE_URL` | Yes (prod) | `postgresql://postgres:postgres@localhost:5432/notifications` | Postgres connection string |
| `LOG_LEVEL` | No | `INFO` | One of `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `APP_ENV` | No | `dev` | Environment label surfaced in `/health` |
| `QUEUE_BACKEND` | No | `memory` | One of: `memory`, `storage`, `servicebus` |
| `STORAGE_QUEUE_ACCOUNT_URL` | If `QUEUE_BACKEND=storage` | — | e.g. `https://mystorage.queue.core.windows.net` |
| `STORAGE_QUEUE_NAME` | If `QUEUE_BACKEND=storage` | — | Queue name |
| `SERVICEBUS_NAMESPACE` | If `QUEUE_BACKEND=servicebus` | — | e.g. `my-ns.servicebus.windows.net` |
| `SERVICEBUS_QUEUE_NAME` | If `QUEUE_BACKEND=servicebus` | — | Queue name |

## Behavior notes that matter for deployment

- Schema is created on startup via `CREATE TABLE IF NOT EXISTS`. The brief asks you to replace this with a proper migration approach.
- The container listens on port 8000 (API only — the worker has no listener).
- The container runs as a non-root user (uid 1001).
- The DB pool initializes eagerly — the app fails to start if Postgres is unreachable. Configure your readiness probe accordingly.
- The queue client is initialized lazily on first use, but the API touches it at startup so misconfiguration surfaces immediately, not on first request.
- The worker handles SIGTERM gracefully — it will finish its current message before exiting. Set a reasonable `terminationGracePeriodSeconds` on its pod.
- Probes: hit `/health` for liveness and `/ready` for readiness. They have different semantics for a reason.

## Run locally

```bash
# Postgres
docker run --rm -d --name pg -p 5432:5432 \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=notifications \
    postgres:16

# Build image
docker build -t notifications:dev .

# In-process smoke test (API only)
docker run --rm -p 8000:8000 \
    -e DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/notifications \
    -e QUEUE_BACKEND=memory \
    notifications:dev

# Send a notification
curl -X POST http://localhost:8000/notify \
    -H "Content-Type: application/json" \
    -d '{"channel":"email","recipient":"test@example.com","message":"hello"}'
```

For end-to-end testing with a real queue, you'll want to either:
1. Deploy to AKS with a provisioned Azure queue, or
2. Run Azurite locally and point `QUEUE_BACKEND=storage` at it.

The in-memory backend doesn't work across the API and worker containers because they're separate processes.

## Tests

```bash
pip install -r requirements.txt pytest
pytest tests/
```

Tests that hit the DB require a running Postgres. The health/metrics smoke tests don't.
