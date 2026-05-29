"""Notification worker.

Consumes notification messages from the queue, simulates sending, and
updates the notification status in Postgres to 'sent'.

Run with: python -m app.worker

Designed to be deployed as its own Kubernetes Deployment (separate from
the API). It shares the same image but is invoked with a different command.
"""
import asyncio
import logging
import random
import signal
from typing import Any

from app.config import settings
from app.db import init_db_pool, get_db_pool, close_db_pool
from app.queue_client import get_queue_client, close_queue_client

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("worker")


async def process_notification(notification_id: str, payload: dict) -> None:
    """Simulate sending a notification and update its status to 'sent'."""
    channel = payload.get("channel", "unknown")
    logger.info("processing notification id=%s channel=%s", notification_id, channel)

    # Simulate variable processing time so a queue actually builds up
    await asyncio.sleep(random.uniform(0.2, 1.0))

    pool = get_db_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE notifications SET status = $1 WHERE id = $2",
            "sent",
            notification_id,
        )
    logger.info("notification sent id=%s", notification_id)


async def write_heartbeat(stop_event: asyncio.Event) -> None:
    """Periodically write the current timestamp to a heartbeat file for K8s liveness probe."""
    import os
    from pathlib import Path
    path = os.environ.get("WORKER_HEARTBEAT_PATH", "/tmp/worker-heartbeat")
    logger.info("starting heartbeat task at %s", path)
    
    # Ensure parent directory exists
    try:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass

    while not stop_event.is_set():
        try:
            with open(path, "w") as f:
                f.write(str(asyncio.get_running_loop().time()))
        except Exception as e:
            logger.error("failed to write heartbeat file: %s", e)
        try:
            await asyncio.sleep(10)
        except asyncio.CancelledError:
            break


async def main() -> None:
    logger.info(
        "worker starting env=%s backend=%s",
        settings.app_env,
        settings.queue_backend,
    )
    await init_db_pool()
    client = get_queue_client()

    # Graceful shutdown on SIGTERM (Kubernetes will send this on pod delete)
    stop_event = asyncio.Event()

    def _request_stop() -> None:
        logger.info("shutdown signal received")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, _request_stop)
        except NotImplementedError:
            # Signal handlers not available on Windows
            pass

    consumer = asyncio.create_task(client.consume(process_notification))
    stop_task = asyncio.create_task(stop_event.wait())
    heartbeat = asyncio.create_task(write_heartbeat(stop_event))

    try:
        done, pending = await asyncio.wait(
            {consumer, stop_task, heartbeat},
            return_when=asyncio.FIRST_COMPLETED,
        )
        for task in pending:
            task.cancel()
    finally:
        logger.info("worker shutting down")
        # Attempt to remove heartbeat file on clean exit
        import os
        path = os.environ.get("WORKER_HEARTBEAT_PATH", "/tmp/worker-heartbeat")
        try:
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass
        await close_queue_client()
        await close_db_pool()
        logger.info("worker stopped")


if __name__ == "__main__":
    asyncio.run(main())
