"""Application settings loaded from environment variables."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str
    log_level: str
    app_env: str
    queue_backend: str

    @classmethod
    def from_env(cls) -> "Settings":
        db_url = os.environ.get("DATABASE_URL")
        if not db_url:
            db_url = "postgresql://postgres:postgres@localhost:5432/notifications"

        return cls(
            database_url=db_url,
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            app_env=os.environ.get("APP_ENV", "dev"),
            queue_backend=os.environ.get("QUEUE_BACKEND", "memory").lower(),
        )


settings = Settings.from_env()
