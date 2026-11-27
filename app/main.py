"""orders-api: small stateless service used to exercise the delivery platform.

Exposes health/readiness probes, Prometheus metrics, structured JSON logs and an
ERROR_RATE fault-injection knob so automated canary rollback can be demonstrated.
"""

import json
import logging
import os
import random
import sys
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

VERSION = os.getenv("APP_VERSION", "dev")
ERROR_RATE = float(os.getenv("ERROR_RATE", "0"))  # 0..1, only affects /orders*


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "msg": record.getMessage(),
            "version": VERSION,
        }
        payload.update(getattr(record, "extra_fields", {}))
        return json.dumps(payload)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
log = logging.getLogger("orders-api")
log.setLevel(logging.INFO)
log.handlers = [handler]
log.propagate = False

REQUESTS = Counter("http_requests_total", "HTTP requests", ["method", "path", "status"])
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)
ORDERS_CREATED = Counter("orders_created_total", "Orders created")

state = {"ready": True}
ORDERS: dict[str, dict] = {}


@asynccontextmanager
async def lifespan(_: FastAPI):
    log.info("startup")
    yield
    state["ready"] = False
    log.info("shutdown")


app = FastAPI(title="orders-api", version=VERSION, lifespan=lifespan)


class OrderIn(BaseModel):
    item: str = Field(min_length=1, max_length=100)
    quantity: int = Field(gt=0, le=1000)


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    injected = (
        ERROR_RATE > 0
        and request.url.path.startswith("/orders")
        and random.random() < ERROR_RATE  # nosec B311
    )
    if injected:
        response = Response(
            '{"detail":"injected failure"}', 500, media_type="application/json"
        )
    else:
        response = await call_next(request)
    elapsed = time.perf_counter() - start
    route = request.scope.get("route")
    path = route.path if route else ("/orders*" if injected else "unmatched")
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    LATENCY.labels(request.method, path).observe(elapsed)
    response.headers["x-request-id"] = request_id
    if path not in ("/healthz", "/readyz", "/metrics"):
        log.info(
            "request",
            extra={
                "extra_fields": {
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status": response.status_code,
                    "duration_ms": round(elapsed * 1000, 2),
                }
            },
        )
    return response


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response):
    if not state["ready"]:
        response.status_code = 503
        return {"status": "shutting-down"}
    return {"status": "ready"}


@app.get("/version")
def version():
    return {"version": VERSION}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/orders", status_code=201)
def create_order(order: OrderIn):
    oid = str(uuid.uuid4())
    ORDERS[oid] = {"id": oid, **order.model_dump()}
    ORDERS_CREATED.inc()
    return ORDERS[oid]


@app.get("/orders")
def list_orders():
    return list(ORDERS.values())


@app.get("/orders/{order_id}")
def get_order(order_id: str):
    if order_id not in ORDERS:
        raise HTTPException(404, "order not found")
    return ORDERS[order_id]
