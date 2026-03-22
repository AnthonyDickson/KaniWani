# KaniWani Architecture

WaniKani-inspired Mandarin learning app. Full-stack Gleam monorepo with a Lustre SPA frontend and a Wisp/Mist backend.

## Repository Structure

```
/
├── client/     # Lustre SPA (compiles to JS)
├── server/     # Wisp HTTP server (runs on Erlang/OTP)
└── shared/     # Shared types, decoders, and utilities
```

## Tech Stack

| Layer    | Technology                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Frontend | [Gleam](https://gleam.run) + [Lustre](https://lustre.build) (SPA, compiled to JS)                                                    |
| Backend  | Gleam + [Wisp](https://github.com/gleam-wisp/wisp) + [Mist](https://github.com/rawhat/mist) (HTTP server on BEAM)                    |
| Database | SQLite via [sqlight](https://github.com/lpil/sqlight)                                                                                |
| Auth     | Session cookies (signed, HttpOnly, Strict SameSite) + [Argus](https://github.com/nicholasgasior/argus) for Argon2id password hashing |
| Styling  | Tailwind CSS (via Lustre dev tools)                                                                                                  |
| Infra    | Docker + Docker Compose                                                                                                              |

## Shared Package

`shared/` is a Gleam library depended on by both client and server. It contains:

- `groceries.gleam` — `GroceryItem` type with JSON encoders/decoders
- `password.gleam` — Password JSON codec + [gzxcvbn](https://github.com/nicholasgasior/gzxcvbn) strength checking
- `api_route.gleam` — Canonical API route definitions (`/api/groceries`, `/api/session`, `/api/register`)

This avoids duplicating serialisation logic across the two targets (JS and Erlang).

## Client (SPA)

Standard Lustre MVU architecture:

```
Model  →  view()  →  HTML
  ↑                    |
  └──── update() ←─────┘ (Msg)
```

**Key modules:**

- `client.gleam` — App entry point, top-level `init/update/view`
- `model.gleam` — Union type covering all page states (`HomePage`, `LogInPage`, `RegisterPage`, `FooPage`, `CheckingAuth`, `NotFoundPage`)
- `msg.gleam` — All messages, split by page (`HomeMsg`, `LogInMsg`, `RegisterMsg`)
- `route.gleam` — Client-side routing via [modem](https://github.com/hayleigh-dot-dev/modem)
- `page/` — Per-page update + view logic
- `effects/session.gleam` — Session check, auto-logout on 401, log-out request
- `effects/router.gleam` — Navigation helpers

Auth flow on startup: `CheckingAuth` → `GET /api/session` → redirect to `Home` or `LogIn`.

## Server

Single-process Wisp app with in-memory session store (OTP Actor).

**Request lifecycle:**

```
Request
  → method_override
  → log_request
  → rescue_crashes
  → handle_head
  → serve_static          (priv/static/)
  → require_valid_session  (skips /api/register, /api/session, /)
  → extend_session
  → route handler
```
