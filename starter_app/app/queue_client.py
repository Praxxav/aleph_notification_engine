"""Queue client abstraction.

Three implementations are provided. Configure via env var QUEUE_BACKEND:

- 'memory'     - in-memory (LOCAL DEV ONLY; does NOT persist across restarts
                 or work across processes)
- 'storage'    - Azure Storage Queue
- 'servicebus' - Azure Service Bus

For Azure backends, authentication uses DefaultAzureCredential, which works
with Workload Identity, Managed Identity, the Azure CLI (for local), and
env-var credentials. You should NOT need to commit any access keys.

You don't need to modify this file for the take-home — wire it up through
Terraform and Kubernetes configuration. Document any deviations.
"""
import asyncio
import json
import logging
import os
from collections import deque
from typing import Any, Awaitable, Callable, Protocol

logger = logging.getLogger(__name__)

Handler = Callable[[str, dict], Awaitable[None]]


class QueueClient(Protocol):
    async def publish(self, notification_id: str, payload: dict) -> None: ...
    async def consume(self, handler: Handler) -> None: ...
    async def close(self) -> None: ...


# --- In-memory implementation (local dev only) ---


class InMemoryQueue:
    """Single-process queue using an asyncio condition variable.

    Useful for unit tests and quick local smoke tests. Does NOT work
    across processes — for cross-process local testing, point the
    Azure backends at Azurite (storage emulator) or a real Azure resource.
    """

    def __init__(self) -> None:
        self._queue: deque = deque()
        self._cond = asyncio.Condition()
        self._closed = False

    async def publish(self, notification_id: str, payload: dict) -> None:
        async with self._cond:
            self._queue.append((notification_id, payload))
            self._cond.notify()

    async def consume(self, handler: Handler) -> None:
        while not self._closed:
            async with self._cond:
                while not self._queue and not self._closed:
                    await self._cond.wait()
                if self._closed:
                    return
                nid, payload = self._queue.popleft()
            try:
                await handler(nid, payload)
            except Exception:
                logger.exception("handler failed id=%s", nid)

    async def close(self) -> None:
        async with self._cond:
            self._closed = True
            self._cond.notify_all()


# --- Azure Storage Queue implementation ---


class AzureStorageQueueClient:
    """Azure Storage Queue backend.

    Required env vars:
    - STORAGE_QUEUE_ACCOUNT_URL: e.g., https://mystorage.queue.core.windows.net
    - STORAGE_QUEUE_NAME: queue name

    Authentication: DefaultAzureCredential (Workload Identity recommended).
    """

    def __init__(self, account_url: str, queue_name: str) -> None:
        # Imported lazily so the in-memory backend works without Azure SDK installed
        from azure.identity.aio import DefaultAzureCredential
        from azure.storage.queue.aio import QueueClient as AzureQueueClient

        self._credential = DefaultAzureCredential()
        self._client = AzureQueueClient(
            account_url=account_url,
            queue_name=queue_name,
            credential=self._credential,
        )

    async def publish(self, notification_id: str, payload: dict) -> None:
        body = json.dumps({"id": notification_id, "payload": payload})
        await self._client.send_message(body)

    async def consume(self, handler: Handler) -> None:
        while True:
            got_any = False
            messages = self._client.receive_messages(
                messages_per_page=8, visibility_timeout=30
            )
            async for msg in messages:
                got_any = True
                try:
                    data = json.loads(msg.content)
                    await handler(data["id"], data["payload"])
                    await self._client.delete_message(msg)
                except Exception:
                    logger.exception("handler failed; message will retry")
            if not got_any:
                await asyncio.sleep(2)

    async def close(self) -> None:
        await self._client.close()
        await self._credential.close()


# --- Azure Service Bus implementation ---


class AzureServiceBusClient:
    """Azure Service Bus backend.

    Required env vars:
    - SERVICEBUS_NAMESPACE: e.g., my-ns.servicebus.windows.net
    - SERVICEBUS_QUEUE_NAME: queue name

    Authentication: DefaultAzureCredential (Workload Identity recommended).
    """

    def __init__(self, namespace: str, queue_name: str) -> None:
        from azure.identity.aio import DefaultAzureCredential
        from azure.servicebus.aio import ServiceBusClient
        from azure.servicebus import ServiceBusMessage

        self._credential = DefaultAzureCredential()
        self._client = ServiceBusClient(
            fully_qualified_namespace=namespace,
            credential=self._credential,
        )
        self._queue_name = queue_name
        self._ServiceBusMessage = ServiceBusMessage

    async def publish(self, notification_id: str, payload: dict) -> None:
        body = json.dumps({"id": notification_id, "payload": payload})
        sender = self._client.get_queue_sender(self._queue_name)
        async with sender:
            await sender.send_messages(self._ServiceBusMessage(body))

    async def consume(self, handler: Handler) -> None:
        receiver = self._client.get_queue_receiver(self._queue_name)
        async with receiver:
            async for msg in receiver:
                try:
                    data = json.loads(str(msg))
                    await handler(data["id"], data["payload"])
                    await receiver.complete_message(msg)
                except Exception:
                    logger.exception("handler failed; abandoning for retry")
                    await receiver.abandon_message(msg)

    async def close(self) -> None:
        await self._client.close()
        await self._credential.close()


# --- Factory ---


_singleton: QueueClient | None = None


def get_queue_client() -> QueueClient:
    """Return a process-wide queue client based on QUEUE_BACKEND env var."""
    global _singleton
    if _singleton is not None:
        return _singleton

    backend = os.environ.get("QUEUE_BACKEND", "memory").lower()
    if backend == "memory":
        _singleton = InMemoryQueue()
    elif backend == "storage":
        url = os.environ["STORAGE_QUEUE_ACCOUNT_URL"]
        name = os.environ["STORAGE_QUEUE_NAME"]
        _singleton = AzureStorageQueueClient(url, name)
    elif backend == "servicebus":
        ns = os.environ["SERVICEBUS_NAMESPACE"]
        name = os.environ["SERVICEBUS_QUEUE_NAME"]
        _singleton = AzureServiceBusClient(ns, name)
    else:
        raise ValueError(
            f"unknown QUEUE_BACKEND: {backend!r} "
            f"(expected one of: memory, storage, servicebus)"
        )
    return _singleton


async def close_queue_client() -> None:
    global _singleton
    if _singleton is not None:
        await _singleton.close()
        _singleton = None
