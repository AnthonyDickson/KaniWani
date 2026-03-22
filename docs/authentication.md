# Authentication Overview

## Purpose

Restrict access to the website to authenticated users only

## Definitions

A **session** is a timeframe spanning from the time the user provides the correct password and until the idle timeout is
or maximum session lifetime is reached, after which the session is then **expired**.
The **idle timeout** is the time between the last API activity for the user and when the session should expire.
The **maximum session lifetime** is the maximum duration for which a single session may be valid.
The **time of issue** is the time a session is created.
A **session cookie** is an opaque token that carries the session ID.
A **session ID** is a UUID v4 string.
A **protected route** is a route that requires a **session cookie** that corresponds to a **session** that is not **expired**.
A **public route** is a route that does not require a valid **session cookie** or **session** for access.

## Requirements

- The client should start logged out and check with the server if it has a valid **session cookie** and:
  - if logged in, redirect to the home page
  - if logged out, redirect to the login page
- While logged out:
  - the server should respond with the status code 401 for protected routes
  - the client should block access to protected routes and allow access to the login and registration pages
- While logged in:
  - the client should block access to the login and registration pages and allow access to protected routes
  - the client should redirect to the login page on a status code 401 response
- The registration page should allow the user to set the password once
  - Passwords should be checked with zxcvbn and have a strength of at least `SomewhatGuessable`
  - Passwords should be hashed with Argon2id
- The client must authenticate by providing a valid password via the login page
  - The server should respond with status code 404 if a password has not been set
  - The server should respond with status code 401 if an incorrect password was provided
- When the correct password is provided, a new **session** should be created on the server and a **session cookie**
  should be set on the client with the following values:

  ```
  Name:      kaniwani_session
  Value:     Wisp-signed session ID (HMAC-SHA512 over SECRET_KEY_BASE)
  Path:      /
  HttpOnly:  true
  Secure:    true
  SameSite:  Strict
  Max-Age:   **maximum session lifetime**
  ```

- **Sessions** should expire after there has been no activity for the duration of the **idle timeout**
- On API activity, the **session** should be extended to expire at the earliest of the **time of issue** plus the
  **maximum session** or the current system time plus the **idle timeout**
- Expired **sessions** should be deleted on a regular schedule
- Logging out should:
  - delete the the **session cookie** from the client
  - delete the **session** from the server
  - redirect the client to the login page

# Supplementary Information

## Auth Flow

```
Register:  POST /api/register  →  gzxcvbn check   →  Argon2id hash  →  INSERT password
Log in:    POST /api/session   →  read hash       →  argus.verify   →  set signed session cookie
Protected: any request         →  read cookie     →  lookup session →  extend or 401
Log out:   DELETE /api/session →  delete session  →  clear cookie
```

## Sessions

Sessions are held in memory in an OTP Actor (`session.gleam`). There is no persistence — sessions are lost on server restart

**Session lifetime:**

- Idle timeout: 15 minutes. Extended on every authenticated request
- Absolute maximum age: 24 hours from `issued_at`. Idle extension will not push expiry past this
- Cleanup: a recurring message fires every 60 s to purge expired sessions from the in-memory store

**Session ID:** UUID v4, stored in a signed cookie

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

The cookie value is signed by Wisp using `SECRET_KEY_BASE`. An attacker cannot forge a valid session ID without the key

## Request Authorisation

Every request passes through the middleware chain in `server.gleam`:

```
serve_static
  → require_valid_session   ← skipped for /, /api/register, /api/session
    → extend_session
      → route handler
```

`require_valid_session`:

1. Extract and verify the signed cookie
2. Look up the session ID in the Actor store
3. Check `now < expires_at`. If expired or missing → `401`

`extend_session`: if a valid session is found, recalculate `expires_at = min(now + 15min, issued_at + 24h)` and write it back to the store. This runs on every request passively, with no extra round-trip

## Client-Side Auth

On startup the SPA enters `CheckingAuth` state and immediately calls `GET /api/session`

- `200` → navigate to `Home`
- `401` → navigate to `LogIn`

Any subsequent API response with `401` triggers `auto_logout` in `effects/session.gleam`, which clears the model and redirects to `/log_in`

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
