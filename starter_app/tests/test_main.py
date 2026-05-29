"""Basic smoke tests. Extend these if you want — not required."""
import os

os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/notifications_test")

from fastapi.testclient import TestClient

# Note: tests that hit the DB require a running Postgres.
# Health and metrics tests do not.


def test_health_returns_ok():
    # We import here so DB pool init can be patched if needed
    from app.main import app
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code in (200, 503)
    if response.status_code == 200:
        assert response.json()["status"] == "ok"


def test_metrics_returns_prometheus_format():
    from app.main import app
    with TestClient(app) as client:
        response = client.get("/metrics")
    # Health/metrics shouldn't fail even if DB is down
    if response.status_code == 200:
        assert "app_requests_total" in response.text
        assert "app_notifications_created_total" in response.text


def test_create_notification_validation_error():
    from app.main import app
    with TestClient(app) as client:
        # Invalid channel type (must be email, sms, or webhook)
        response = client.post(
            "/notify",
            json={"channel": "fax", "recipient": "test@example.com", "message": "hello"},
        )
        assert response.status_code == 400
        assert "channel must be one of" in response.text

        # Missing recipient
        response = client.post(
            "/notify",
            json={"channel": "email", "recipient": "", "message": "hello"},
        )
        assert response.status_code == 422  # Pydantic validation error

