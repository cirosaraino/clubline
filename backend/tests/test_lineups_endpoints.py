"""Lineups + auth smoke/regression tests for public deployed API."""

import os
import uuid
from datetime import datetime, timedelta, timezone

import pytest
import requests


BASE_URL = os.environ.get("REACT_APP_BACKEND_URL")


@pytest.fixture(scope="session")
def base_url() -> str:
    if not BASE_URL:
        pytest.skip("REACT_APP_BACKEND_URL non configurata: impossibile eseguire test API pubbliche")
    return BASE_URL.rstrip("/")


@pytest.fixture
def api_client() -> requests.Session:
    session = requests.Session()
    session.headers.update({"Accept": "application/json"})
    return session


# Module: basic API reachability
def test_health_ok(api_client: requests.Session, base_url: str):
    response = api_client.get(f"{base_url}/api/health", timeout=20)
    assert response.status_code == 200
    payload = response.json()
    assert payload.get("status") == "ok"


# Module: lineups listing and response schema
def test_list_lineups_returns_wrapped_collection(api_client: requests.Session, base_url: str):
    response = api_client.get(f"{base_url}/api/lineups", timeout=20)
    assert response.status_code == 200
    payload = response.json()
    assert isinstance(payload.get("lineups"), list)


# Module: route precedence/specific route smoke for /all
def test_delete_all_without_auth_returns_401_not_404(
    api_client: requests.Session,
    base_url: str,
):
    response = api_client.delete(f"{base_url}/api/lineups/all", timeout=20)
    assert response.status_code == 401
    payload = response.json()
    assert "error" in payload and "message" in payload["error"]


def test_delete_all_with_fake_bearer_returns_401(
    api_client: requests.Session,
    base_url: str,
):
    response = api_client.delete(
        f"{base_url}/api/lineups/all",
        headers={"Authorization": "Bearer invalid-token-for-smoke-test"},
        timeout=20,
    )
    assert response.status_code == 401
    payload = response.json()
    assert "error" in payload and "message" in payload["error"]


# Module: auth bootstrap for protected flow checks
def test_register_and_login_smoke(api_client: requests.Session, base_url: str):
    email = f"test.lineups.{uuid.uuid4().hex[:10]}@example.com"
    password = "Test1234!"

    register_response = api_client.post(
        f"{base_url}/api/auth/register",
        json={"email": email, "password": password},
        timeout=20,
    )
    assert register_response.status_code in (200, 201)
    register_payload = register_response.json()
    assert "session" in register_payload

    login_response = api_client.post(
        f"{base_url}/api/auth/login",
        json={"email": email, "password": password},
        timeout=20,
    )
    assert login_response.status_code == 200
    login_payload = login_response.json()
    assert "session" in login_payload
    assert isinstance(login_payload["session"].get("accessToken"), str)


def test_delete_all_with_authenticated_non_manager_user_is_rejected_or_allowed(
    api_client: requests.Session,
    base_url: str,
):
    email = f"test.lineups.auth.{uuid.uuid4().hex[:10]}@example.com"
    password = "Test1234!"

    register_response = api_client.post(
        f"{base_url}/api/auth/register",
        json={"email": email, "password": password},
        timeout=20,
    )
    assert register_response.status_code in (200, 201)
    token = register_response.json().get("session", {}).get("accessToken")
    assert isinstance(token, str) and len(token) > 0

    delete_response = api_client.delete(
        f"{base_url}/api/lineups/all",
        headers={"Authorization": f"Bearer {token}"},
        timeout=20,
    )
    assert delete_response.status_code in (204, 403)


# Module: single-lineup CRUD regression (executes only if account can manage lineups)
def test_single_lineup_create_update_delete_regression_if_manager(
    api_client: requests.Session,
    base_url: str,
):
    email = f"test.lineups.manager.{uuid.uuid4().hex[:10]}@example.com"
    password = "Test1234!"

    register_response = api_client.post(
        f"{base_url}/api/auth/register",
        json={"email": email, "password": password},
        timeout=20,
    )
    assert register_response.status_code in (200, 201)
    session = register_response.json().get("session", {})
    token = session.get("accessToken")
    assert isinstance(token, str) and len(token) > 0

    claim_payload = {
        "nome": "TEST",
        "cognome": "Manager",
        "id_console": f"TEST-CONSOLE-{uuid.uuid4().hex[:8]}",
        "account_email": email,
        "team_role": "captain",
    }
    claim_response = api_client.post(
        f"{base_url}/api/players/claim",
        headers={"Authorization": f"Bearer {token}"},
        json=claim_payload,
        timeout=20,
    )
    assert claim_response.status_code in (200, 201)

    match_at = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    create_payload = {
        "competition_name": f"TEST_COMP_{uuid.uuid4().hex[:6]}",
        "match_datetime": match_at,
        "opponent_name": "TEST_OPP",
        "formation_module": "4-3-3",
        "notes": "TEST_NOTE",
    }
    create_response = api_client.post(
        f"{base_url}/api/lineups",
        headers={"Authorization": f"Bearer {token}"},
        json=create_payload,
        timeout=20,
    )

    if create_response.status_code == 403:
        pytest.skip("Utente registrato non ha canManageLineups nel deploy corrente")

    assert create_response.status_code == 201
    created = create_response.json().get("lineup", {})
    assert created.get("competition_name") == create_payload["competition_name"]
    assert created.get("formation_module") == create_payload["formation_module"]
    lineup_id = created.get("id")
    assert lineup_id is not None

    update_payload = {
        "competition_name": f"{create_payload['competition_name']}_UPD",
        "match_datetime": match_at,
        "opponent_name": "TEST_OPP_UPD",
        "formation_module": "3-5-2",
        "notes": "TEST_NOTE_UPD",
    }
    update_response = api_client.put(
        f"{base_url}/api/lineups/{lineup_id}",
        headers={"Authorization": f"Bearer {token}"},
        json=update_payload,
        timeout=20,
    )
    assert update_response.status_code == 200
    updated = update_response.json().get("lineup", {})
    assert updated.get("competition_name") == update_payload["competition_name"]
    assert updated.get("formation_module") == update_payload["formation_module"]

    list_response = api_client.get(f"{base_url}/api/lineups", timeout=20)
    assert list_response.status_code == 200
    all_lineups = list_response.json().get("lineups", [])
    fetched = next((item for item in all_lineups if str(item.get("id")) == str(lineup_id)), None)
    assert fetched is not None
    assert fetched.get("competition_name") == update_payload["competition_name"]

    delete_response = api_client.delete(
        f"{base_url}/api/lineups/{lineup_id}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=20,
    )
    assert delete_response.status_code == 204

    verify_list_response = api_client.get(f"{base_url}/api/lineups", timeout=20)
    assert verify_list_response.status_code == 200
    verify_lineups = verify_list_response.json().get("lineups", [])
    assert not any(str(item.get("id")) == str(lineup_id) for item in verify_lineups)
