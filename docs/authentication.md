# Authentication Overview

KaniWani is a single-user app. There are no usernames — auth is purely password-based. A valid session cookie is required to access any API route except registration, login, and the index.

## Auth Flow

```
Register:  POST /api/register  →  gzxcvbn check   →  Argon2id hash  →  INSERT password
Log in:    POST /api/session   →  read hash       →  argus.verify   →  set signed session cookie
Protected: any request         →  read cookie     →  lookup session →  extend or 401
Log out:   DELETE /api/session →  delete session  →  clear cookie
```

## Sessions

Sessions are held in memory in an OTP Actor (`session.gleam`). There is no persistence — sessions are lost on server restart.

**Session lifetime:**

- Idle timeout: 15 minutes. Extended on every authenticated request.
- Absolute maximum age: 24 hours from `issued_at`. Idle extension will not push expiry past this.
- Cleanup: a recurring message fires every 60 s to purge expired sessions from the in-memory store.

**Session ID:** UUID v4, stored in a signed cookie.

**Cookie attributes:**

```
Name:      kaniwani_session
Value:     Wisp-signed session ID (HMAC-SHA512 over SECRET_KEY_BASE)
Path:      /
HttpOnly:  true
Secure:    true
SameSite:  Strict
Max-Age:   86400 (24 h)
```

The cookie value is signed by Wisp using `SECRET_KEY_BASE`. An attacker cannot forge a valid session ID without the key.

## Request Authorisation

Every request passes through the middleware chain in `server.gleam`:

```
serve_static
  → require_valid_session   ← skipped for /, /api/register, /api/session
    → extend_session
      → route handler
```

`require_valid_session`:

1. Extract and verify the signed cookie.
2. Look up the session ID in the Actor store.
3. Check `now < expires_at`. If expired or missing → `401`.

`extend_session`: if a valid session is found, recalculate `expires_at = min(now + 15min, issued_at + 24h)` and write it back to the store. This runs on every request passively, with no extra round-trip.

## Client-Side Auth

On startup the SPA enters `CheckingAuth` state and immediately calls `GET /api/session`.

- `200` → navigate to `Home`.
- `401` → navigate to `LogIn`.

Any subsequent API response with `401` triggers `auto_logout` in `effects/session.gleam`, which clears the model and redirects to `/log_in`.

## Sequence Diagrams

### Registration

```
Client                        Server
  |                              |
  |-- POST /api/register ------->|
  |   { password }               |
  |                              |-gzxcvbn strength check
  |                              |-Argon2id hash
  |                              |-INSERT INTO password
  |<-- 204 No Content -----------|
  |                              |
  | (redirect to /log_in)        |
```

### Login

```
Client                        Server
  |                              |
  |-- POST /api/session -------->|
  |   { password }               |
  |                              |-SELECT password_hash
  |                              |-argus.verify
  |                              |-create session (UUID v4)
  |<-- 204 + Set-Cookie ---------|
  |                              |
  | (redirect to /home)          |
```

### Authenticated Request

```
Client                        Server                   Session Store
  |                              |                           |
  |-- GET /api/foo       ------->|                           |
  |   Cookie: kaniwani_session   |                           |
  |                              |-verify signature          |
  |                              |                           |
  |                              |-- get(session_id) ------->|
  |                              |                           |
  |                              |<-- Session ---------------|
  |                              |                           |
  |                              |-check expiry              |
  |                              |                           |
  |                              |-- extend & set ---------->|
  |<-- 200 OK -------------------|                           |
```
