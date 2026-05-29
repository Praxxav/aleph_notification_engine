"""Database pool management."""
import logging
from typing import Optional

import asyncpg

from app.config import settings

logger = logging.getLogger(__name__)

_pool: Optional[asyncpg.Pool] = None

SCHEMA = """
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY,
    channel VARCHAR(50) NOT NULL,
    recipient VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'queued',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at
    ON notifications (created_at DESC);
"""


async def init_db_pool() -> None:
    """Create the connection pool and ensure the schema exists."""
    global _pool
    logger.info("creating db pool")
    _pool = await asyncpg.create_pool(
        settings.database_url,
        min_size=1,
        max_size=5,
        command_timeout=10,
    )
    if settings.app_env == "test":
        logger.info("running schema init for test environment")
        async with _pool.acquire() as conn:
            await conn.execute(SCHEMA)
    logger.info("db pool ready")


def get_db_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("db pool not initialized")
    return _pool


async def close_db_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
