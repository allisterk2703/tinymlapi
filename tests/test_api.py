"""
Integration tests for tinymlapi — Flask and FastAPI.

Both containers must be running before executing the tests:
  FastAPI : docker run --rm -d -p 8000:8000 tinymlapi-image-fastapi
  Flask   : docker run --rm -d -p 5001:5000 tinymlapi-image-flask

Install  : make venv
Run      : make test-unit
"""

import pytest
import requests

FRAMEWORKS = [
    pytest.param(("fastapi", "http://127.0.0.1:8000"), id="fastapi"),
    pytest.param(("flask",   "http://127.0.0.1:5001"), id="flask"),
]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(params=FRAMEWORKS)
def api(request):
    """Returns (framework_name, base_url) for each implementation."""
    return request.param


# ---------------------------------------------------------------------------
# GET /
# ---------------------------------------------------------------------------

class TestIndex:
    def test_returns_200(self, api):
        _, base_url = api
        assert requests.get(f"{base_url}/").status_code == 200

    def test_body_contains_service(self, api):
        _, base_url = api
        assert requests.get(f"{base_url}/").json()["service"] == "tinymlapi"

    def test_body_contains_correct_framework(self, api):
        framework, base_url = api
        assert requests.get(f"{base_url}/").json()["framework"] == framework

    def test_body_contains_endpoints(self, api):
        _, base_url = api
        data = requests.get(f"{base_url}/").json()
        assert "/health" in data["endpoints"]
        assert "/invocations" in data["endpoints"]


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------

class TestHealth:
    def test_returns_200(self, api):
        _, base_url = api
        assert requests.get(f"{base_url}/health").status_code == 200

    def test_body_status_ok(self, api):
        _, base_url = api
        assert requests.get(f"{base_url}/health").json() == {"status": "ok"}

    def test_content_type_json(self, api):
        _, base_url = api
        r = requests.get(f"{base_url}/health")
        assert "application/json" in r.headers["Content-Type"]


# ---------------------------------------------------------------------------
# POST /invocations — nominal cases
# ---------------------------------------------------------------------------

class TestInvocationsNominal:
    def test_returns_200(self, api):
        _, base_url = api
        r = requests.post(f"{base_url}/invocations", json={"min_val": 10, "max_val": 50})
        assert r.status_code == 200

    def test_body_contains_value_and_range(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 10, "max_val": 50}).json()
        assert "value" in data
        assert "range" in data

    def test_value_within_range(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 10, "max_val": 50}).json()
        assert 10 <= data["value"] <= 50

    def test_range_format(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 10, "max_val": 50}).json()
        assert data["range"] == "10-50"

    def test_min_equals_max(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 42, "max_val": 42}).json()
        assert data["value"] == 42
        assert data["range"] == "42-42"

    def test_large_values(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 0, "max_val": 1_000_000}).json()
        assert 0 <= data["value"] <= 1_000_000

    def test_negative_values(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": -100, "max_val": -1}).json()
        assert -100 <= data["value"] <= -1

    def test_zero(self, api):
        _, base_url = api
        data = requests.post(f"{base_url}/invocations", json={"min_val": 0, "max_val": 0}).json()
        assert data["value"] == 0

    def test_randomness_across_calls(self, api):
        """Checks that the value is not always the same (probabilistic)."""
        _, base_url = api
        values = {
            requests.post(f"{base_url}/invocations", json={"min_val": 1, "max_val": 1000}).json()["value"]
            for _ in range(10)
        }
        assert len(values) > 1


# ---------------------------------------------------------------------------
# POST /invocations — validation errors
# ---------------------------------------------------------------------------

class TestInvocationsErrors:
    def test_min_greater_than_max_returns_400(self, api):
        _, base_url = api
        r = requests.post(f"{base_url}/invocations", json={"min_val": 50, "max_val": 10})
        assert r.status_code == 400

    def test_min_greater_than_max_error_message(self, api):
        _, base_url = api
        body = requests.post(f"{base_url}/invocations", json={"min_val": 50, "max_val": 10}).text
        assert "min_val" in body.lower() or "max_val" in body.lower()

    def test_empty_payload_returns_4xx(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/invocations", json={}).status_code in (400, 422)

    def test_wrong_fields_returns_4xx(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/invocations", json={"wrong": "data"}).status_code in (400, 422)

    def test_wrong_content_type_returns_4xx(self, api):
        _, base_url = api
        r = requests.post(
            f"{base_url}/invocations",
            data="not json",
            headers={"Content-Type": "text/plain"},
        )
        assert r.status_code in (400, 415, 422)

    def test_missing_min_val_returns_4xx(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/invocations", json={"max_val": 50}).status_code in (400, 422)

    def test_missing_max_val_returns_4xx(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/invocations", json={"min_val": 10}).status_code in (400, 422)


# ---------------------------------------------------------------------------
# Unknown routes
# ---------------------------------------------------------------------------

class TestUnknownRoutes:
    def test_get_unknown_returns_404(self, api):
        _, base_url = api
        assert requests.get(f"{base_url}/unknown").status_code == 404

    def test_post_unknown_returns_404_or_405(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/unknown", json={}).status_code in (404, 405)

    def test_post_on_health_returns_4xx(self, api):
        _, base_url = api
        assert requests.post(f"{base_url}/health").status_code in (400, 405)
