from fastapi.testclient import TestClient

import main

client = TestClient(main.app)


def test_health_and_ready():
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").status_code == 200


def test_version():
    assert "version" in client.get("/version").json()


def test_create_and_get_order():
    r = client.post("/orders", json={"item": "book", "quantity": 2})
    assert r.status_code == 201
    oid = r.json()["id"]
    assert client.get(f"/orders/{oid}").json()["item"] == "book"
    assert any(o["id"] == oid for o in client.get("/orders").json())


def test_validation_and_404():
    assert client.post("/orders", json={"item": "", "quantity": 0}).status_code == 422
    assert client.get("/orders/nope").status_code == 404


def test_metrics_exposed():
    client.get("/healthz")
    body = client.get("/metrics").text
    assert (
        "http_requests_total" in body and "http_request_duration_seconds_bucket" in body
    )


def test_fault_injection(monkeypatch):
    monkeypatch.setattr(main, "ERROR_RATE", 1.0)
    assert client.get("/orders").status_code == 500
    assert client.get("/healthz").status_code == 200  # probes unaffected
