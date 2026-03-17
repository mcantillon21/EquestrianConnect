#!/usr/bin/env python3
"""
Base44 API tests for EquestrianConnect.

Usage:
    python3 scripts/test_backend.py <email> <password>

What it tests:
    1. Login — verifies credentials and gets a token
    2. /me   — verifies the token works and returns your user
    3. Users — lists every user who has ever signed up
    4. Entities — lists Horse, CalendarEvent, Conversation, HorseListing records
    5. Token persistence — confirms the token is reusable across requests
"""
import sys
import json
import urllib.request
import urllib.error

APP_ID   = "695f71cb4f1b571a35a55ba2"
BASE_URL = "https://base44.app/api"

# ── Helpers ──────────────────────────────────────────────────────────────────

def api(method, path, body=None, token=None):
    """Make a JSON request. Returns (status_code, parsed_body)."""
    url = f"{BASE_URL}{path}"
    headers = {
        "Content-Type": "application/json",
        "Accept":       "application/json",
        "X-App-Id":     APP_ID,
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"raw": raw.decode(errors="replace")}
        return e.code, parsed
    except Exception as e:
        return None, str(e)

def ok(msg):    print(f"  \u2713 {msg}")
def fail(msg):  print(f"  \u2717 {msg}")
def section(s): print(f"\n\u2500\u2500 {s} \u2500\u2500")

def items_from(resp):
    """Base44 returns either a plain list or {items: [...]}."""
    if isinstance(resp, list):
        return resp
    if isinstance(resp, dict):
        return resp.get("items") or resp.get("results") or []
    return []

# ── Test runner ───────────────────────────────────────────────────────────────

def run(email, password):
    print(f"\nEquestrianConnect — Base44 Backend Tests")
    print(f"  App ID : {APP_ID}")
    print(f"  User   : {email}")

    token = None

    # ── 1. Login ──────────────────────────────────────────────────────────────
    section("1. Login")
    status, resp = api("POST", f"/apps/{APP_ID}/auth/login",
                       body={"email": email, "password": password})

    if status == 200 and isinstance(resp, dict) and resp.get("access_token"):
        token = resp["access_token"]
        ok(f"Login succeeded  (token starts: {token[:24]}...)")
        if resp.get("user"):
            u = resp["user"]
            ok(f"User in response — name: {u.get('full_name','(none)')!r}  "
               f"email: {u.get('email','?')}  role: {u.get('user_type','none')}")
    elif status == 401 or status == 403:
        fail(f"Login failed (HTTP {status}) — wrong email or password")
        msg = resp.get("message") or resp.get("detail") or repr(resp)
        print(f"     Server said: {msg}")
        print("\n  >>> Check that this account exists in Base44 and the password is correct.")
        print("  >>> If you have not created an account yet, use the app's 'Create one' button")
        print("      on a real device to register first.\n")
        return
    else:
        fail(f"Unexpected response (HTTP {status}): {resp}")
        return

    # ── 2. /me ────────────────────────────────────────────────────────────────
    section("2. Current user (/me)")
    status, resp = api("GET", f"/apps/{APP_ID}/entities/User/me", token=token)
    if status == 200 and isinstance(resp, dict):
        ok(f"id={resp.get('id','?')}  "
           f"email={resp.get('email','?')}  "
           f"role={resp.get('user_type') or 'not set'}")
    else:
        fail(f"/me failed (HTTP {status}): {resp}")

    # ── 3. All users ──────────────────────────────────────────────────────────
    section("3. All registered users")
    status, resp = api("GET", f"/apps/{APP_ID}/entities/User", token=token)
    if status == 200:
        users = items_from(resp)
        ok(f"{len(users)} user(s) found\n")
        col = "{:<30} {:<40} {:<12}"
        print("     " + col.format("Name", "Email", "Role"))
        print("     " + "-" * 84)
        for u in users:
            name  = (u.get("full_name") or "(no name)")[:28]
            email = (u.get("email")     or "?")[:38]
            role  = u.get("user_type")  or "no role"
            print("     " + col.format(name, email, role))
    else:
        fail(f"Could not list users (HTTP {status}): {resp}")

    # ── 4. Entity counts ──────────────────────────────────────────────────────
    section("4. Entity record counts")
    entities = [
        ("Horse",         "Horses"),
        ("CalendarEvent", "Calendar events"),
        ("Conversation",  "Conversations"),
        ("Message",       "Messages"),
        ("HorseListing",  "Marketplace listings"),
    ]
    for entity, label in entities:
        status, resp = api("GET", f"/apps/{APP_ID}/entities/{entity}", token=token)
        if status == 200:
            count = len(items_from(resp))
            ok(f"{label}: {count} record(s)")
        elif status == 404:
            fail(f"{label}: entity not found on server (404) — may not be created yet")
        else:
            fail(f"{label}: HTTP {status}")

    # ── 5. Token persistence ──────────────────────────────────────────────────
    section("5. Token persistence")
    status, resp = api("GET", f"/apps/{APP_ID}/entities/User/me", token=token)
    if status == 200:
        ok("Token is still valid after multiple requests")
    else:
        fail(f"Token no longer valid (HTTP {status}) — sessions may be very short-lived")

    print("\n\u2500\u2500 All tests complete \u2500\u2500\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 scripts/test_backend.py <email> <password>")
        sys.exit(1)
    run(sys.argv[1], sys.argv[2])
