"""Notification Service API for the Aleph DevOps take-home.

A FastAPI service that accepts notification requests, persists them to
Postgres, and publishes them to a queue for asynchronous processing
by a separate worker.
"""
import logging
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field

from app.config import settings
from app.db import init_db_pool, get_db_pool, close_db_pool
from app.queue_client import get_queue_client, close_queue_client

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


# --- Models ---


class NotificationIn(BaseModel):
    channel: str = Field(..., description="One of: email, sms, webhook")
    recipient: str = Field(..., min_length=1, max_length=255)
    message: str = Field(..., min_length=1, max_length=4000)


class NotificationOut(BaseModel):
    id: str
    channel: str
    recipient: str
    message: str
    status: str
    created_at: datetime


# --- Metrics (in-memory; a real implementation would use prometheus_client) ---


metrics = {
    "requests_total": 0,
    "notifications_created_total": 0,
    "queue_publish_failures_total": 0,
    "errors_total": 0,
}


# --- Lifespan ---


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and tear down resources with the app lifecycle."""
    logger.info(
        "starting notification api env=%s queue=%s",
        settings.app_env,
        settings.queue_backend,
    )
    await init_db_pool()
    # Touch the queue client to surface config errors at startup, not first request
    get_queue_client()
    yield
    await close_queue_client()
    await close_db_pool()
    logger.info("notification api stopped")


app = FastAPI(title="Aleph Notification Engine", version="0.1.0", lifespan=lifespan)


# --- Middleware ---


@app.middleware("http")
async def count_requests(request: Request, call_next):
    metrics["requests_total"] += 1
    try:
        response = await call_next(request)
    except Exception:
        metrics["errors_total"] += 1
        raise
    return response


# --- Routes ---


@app.post("/notify", response_model=NotificationOut, status_code=201)
async def create_notification(payload: NotificationIn) -> NotificationOut:
    if payload.channel not in ("email", "sms", "webhook"):
        raise HTTPException(400, "channel must be one of: email, sms, webhook")

    nid = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    pool = get_db_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO notifications (id, channel, recipient, message, status, created_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            """,
            nid, payload.channel, payload.recipient, payload.message, "queued", now,
        )

    # Publish to the queue for worker processing
    try:
        await get_queue_client().publish(
            nid,
            {
                "channel": payload.channel,
                "recipient": payload.recipient,
                "message": payload.message,
            },
        )
    except Exception:
        metrics["queue_publish_failures_total"] += 1
        logger.exception("queue publish failed id=%s — notification stuck in 'queued'", nid)
        # Note: the notification row is still persisted with status='queued'.
        # A reconciliation job (not in scope for this take-home) would re-publish.

    metrics["notifications_created_total"] += 1
    logger.info("notification created id=%s channel=%s", nid, payload.channel)

    return NotificationOut(
        id=nid,
        channel=payload.channel,
        recipient=payload.recipient,
        message=payload.message,
        status="queued",
        created_at=now,
    )


@app.get("/notify/{nid}", response_model=NotificationOut)
async def get_notification(nid: str) -> NotificationOut:
    pool = get_db_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT id, channel, recipient, message, status, created_at
            FROM notifications WHERE id = $1
            """,
            nid,
        )
    if row is None:
        raise HTTPException(404, "notification not found")
    return NotificationOut(
        id=str(row["id"]),
        channel=row["channel"],
        recipient=row["recipient"],
        message=row["message"],
        status=row["status"],
        created_at=row["created_at"],
    )


@app.get("/health")
async def health() -> dict:
    """Liveness probe — returns 200 if the process is up."""
    return {"status": "ok", "env": settings.app_env}


@app.get("/ready")
async def ready() -> dict:
    """Readiness probe — returns 200 only if the DB is reachable."""
    pool = get_db_pool()
    try:
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
    except Exception as exc:
        raise HTTPException(503, f"db not ready: {exc}")
    return {"status": "ready"}


@app.get("/metrics")
async def prometheus_metrics() -> Response:
    """Prometheus-format metrics endpoint."""
    lines = [
        "# HELP app_requests_total Total HTTP requests received",
        "# TYPE app_requests_total counter",
        f"app_requests_total {metrics['requests_total']}",
        "# HELP app_notifications_created_total Total notifications created",
        "# TYPE app_notifications_created_total counter",
        f"app_notifications_created_total {metrics['notifications_created_total']}",
        "# HELP app_queue_publish_failures_total Total queue publish failures",
        "# TYPE app_queue_publish_failures_total counter",
        f"app_queue_publish_failures_total {metrics['queue_publish_failures_total']}",
        "# HELP app_errors_total Total HTTP errors raised",
        "# TYPE app_errors_total counter",
        f"app_errors_total {metrics['errors_total']}",
    ]
    return Response(content="\n".join(lines) + "\n", media_type="text/plain")
