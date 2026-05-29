"""Lightweight database migration runner using asyncpg."""
import asyncio
import logging
import os
import re
import sys
from pathlib import Path
import asyncpg

from app.config import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("migrations")


async def run_migrations() -> None:
    """Run database migrations in alphabetical order."""
    logger.info("Starting database migrations...")
    db_url = settings.database_url
    
    # Connect directly to the database
    try:
        conn = await asyncpg.connect(db_url)
    except Exception as e:
        logger.error("Failed to connect to database: %s", e)
        sys.exit(1)
        
    try:
        # 1. Create schema_migrations tracking table
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """
        )
        
        # 2. Get list of already applied migrations
        rows = await conn.fetch("SELECT version FROM schema_migrations")
        applied = {row["version"] for row in rows}
        
        # 3. Scan the migrations directory
        migrations_dir = Path(__file__).parent / "migrations"
        if not migrations_dir.exists():
            logger.warning("Migrations directory '%s' not found. Creating it.", migrations_dir)
            migrations_dir.mkdir(parents=True, exist_ok=True)
            
        sql_files = sorted(
            [f for f in migrations_dir.iterdir() if f.is_file() and f.suffix == ".sql"],
            key=lambda x: x.name
        )
        
        if not sql_files:
            logger.info("No migrations found to apply.")
            return

        # 4. Run unapplied migrations inside a transaction
        for file_path in sql_files:
            version = file_path.name
            if version in applied:
                logger.debug("Migration '%s' is already applied.", version)
                continue
                
            logger.info("Applying migration '%s'...", version)
            sql_content = file_path.read_text(encoding="utf-8")
            
            async with conn.transaction():
                # Execute the migration SQL
                await conn.execute(sql_content)
                # Record that the migration has been successfully applied
                await conn.execute(
                    "INSERT INTO schema_migrations (version) VALUES ($1)",
                    version
                )
            logger.info("Successfully applied migration '%s'", version)
            
        logger.info("Migrations completed successfully.")
        
    except Exception as e:
        logger.exception("Migration failed: %s", e)
        sys.exit(1)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(run_migrations())
