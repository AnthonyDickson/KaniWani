import gleam/bool
import gleam/crypto
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/http/cookie
import gleam/http/response
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/otp/actor.{type Next}
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

import wisp.{type Request, type Response, Signed}
import youid/uuid

const session_cookie_name = "kaniwani_session"

const idle_timeout_minutes: Int = 15

const max_session_age_hours: Int = 24

const status_unauthorised = 401

//----------------------------------------------------------------------------//
// Domain
//----------------------------------------------------------------------------//

type SessionId =
  String

pub opaque type Session {
  Session(id: SessionId, issued_at: Timestamp, expires_at: Timestamp)
}

/// Extend the session expiry up to the default idle timeout.
///
/// The session will not be extended past its maximum age.
/// Expired sessions will not be extended.
fn extend(session: Session, from now: Timestamp) -> Session {
  let new_expiry = timestamp.add(now, duration.minutes(idle_timeout_minutes))

  let max_expiry =
    timestamp.add(session.issued_at, duration.hours(max_session_age_hours))

  let expires_at = case timestamp.compare(new_expiry, max_expiry) {
    Lt -> new_expiry
    Eq | Gt -> max_expiry
  }

  Session(..session, expires_at:)
}

fn is_expired(session: Session, now: Timestamp) -> Bool {
  case timestamp.compare(now, session.expires_at) {
    Lt -> False
    Eq | Gt -> True
  }
}

//----------------------------------------------------------------------------//
// Session Store (Actor)
//----------------------------------------------------------------------------//

pub type SessionStore =
  Subject(Message)

pub opaque type Message {
  Set(Session)
  Get(reply_with: Subject(Option(Session)), id: SessionId)
  Delete(SessionId)
}

type State =
  dict.Dict(SessionId, Session)

fn handle_message(state: State, message: Message) -> Next(State, Message) {
  case message {
    Set(session) ->
      actor.continue(dict.insert(into: state, for: session.id, insert: session))

    Get(reply_with: client, id:) -> {
      process.send(client, dict.get(state, id) |> option.from_result)
      actor.continue(state)
    }

    Delete(id) -> actor.continue(dict.delete(from: state, delete: id))
  }
}

pub fn start_store() {
  actor.new(dict.new()) |> actor.on_message(handle_message) |> actor.start
}

/// Create a session starting at the given timestamp and add it to the session store
pub fn create(session_store: SessionStore, issued_at now: Timestamp) -> Session {
  let session =
    Session(
      id: uuid.v4_string(),
      issued_at: now,
      expires_at: timestamp.add(now, duration.minutes(idle_timeout_minutes)),
    )
  process.send(session_store, Set(session))
  session
}

fn get(session_store: SessionStore, id: SessionId) -> Option(Session) {
  process.call(session_store, waiting: 10, sending: Get(_, id))
}

fn set(session_store: SessionStore, session: Session) -> Nil {
  process.send(session_store, Set(session))
}

//----------------------------------------------------------------------------//
// Session Cookies
//----------------------------------------------------------------------------//

pub fn set_session_cookie(
  session: Session,
  req: Request,
  response: Response,
  now: Timestamp,
) -> Response {
  let Session(id:, issued_at: _, expires_at:) = session
  let max_age_seconds =
    timestamp.difference(now, expires_at)
    |> duration.to_seconds
    |> float.round
    |> to_non_negative_int

  set_cookie(
    response:,
    request: req,
    name: session_cookie_name,
    value: id,
    max_age_seconds:,
  )
}

pub fn require_valid_session_cookie(
  req: Request,
  session_store: SessionStore,
  now: Timestamp,
  next: fn() -> Response,
) -> Response {
  case has_valid_session_cookie(req, session_store, now) {
    False -> wisp.response(status_unauthorised)
    True -> next()
  }
}

pub fn handle_validate_session_cookie(
  req: Request,
  session_store: SessionStore,
  now: Timestamp,
) -> Response {
  case has_valid_session_cookie(req, session_store, now) {
    True -> wisp.no_content()
    False -> wisp.response(status_unauthorised)
  }
}

/// Delete the session corresponding to the session cookie in `req`, if the
/// cookie exists and delete the session cookie.
///
/// See `delete_session` for just deleting the session.
pub fn handle_delete_session(
  req: Request,
  session_store: SessionStore,
) -> Response {
  delete_session(req, session_store)
  set_cookie(wisp.no_content(), req, session_cookie_name, "", 0)
}

/// Delete the session corresponding to the session cookie in `req`, if the cookie exists.
///
/// See `handle_delete_session` for the route handler that deletes the session
/// cookie as well as the session.
pub fn delete_session(req: Request, session_store: SessionStore) -> Nil {
  case get_cookie(req) {
    Some(session_id) -> process.send(session_store, Delete(session_id))
    None -> Nil
  }
}

/// Extend the expiry of a session and set the session cookie.
/// 
/// Intended to be used as middle after the request has been handled.
pub fn extend_cookie(
  session_store: SessionStore,
  req: Request,
  now: Timestamp,
  next: fn() -> Response,
) -> Response {
  let response = next()

  use session_id <- try_get(get_cookie(req), or: response)
  use session <- try_get(get(session_store, session_id), or: response)
  use <- bool.guard(when: is_expired(session, now), return: response)

  let session = extend(session, from: now)
  set(session_store, session)
  // When logging in, this could potentially override the newly created session cookie.
  // This will not be an issue so long as the login endpoint checks for a session
  // cookie in the request and if it exists, deletes the corresponding session.
  //
  // This code will not override the logout cookie (MaxAge set to zero for deletion)
  // so long as the logout endpoint deletes the session corresponding to the
  // request cookie. This would cause the call to `get(..)` to return `None` and
  // then `try_get(..)` to return the unmodified response.
  //
  // All other requests should not touch the session, therefore setting cookie
  // here should be safe.
  set_session_cookie(session, req, response, now)
}

fn try_get(option: Option(a), or default: b, next next: fn(a) -> b) -> b {
  case option {
    Some(value) -> next(value)
    None -> default
  }
}

fn has_valid_session_cookie(
  req: Request,
  session_store: SessionStore,
  now: Timestamp,
) -> Bool {
  case get_cookie(req) {
    Some(session_id) -> {
      case process.call(session_store, 10, Get(_, id: session_id)) {
        Some(session) -> !is_expired(session, now)
        None -> False
      }
    }
    None -> False
  }
}

fn get_cookie(req: Request) {
  wisp.get_cookie(req, session_cookie_name, Signed) |> option.from_result
}

fn set_cookie(
  response response_: Response,
  request request: Request,
  name name: String,
  value value: String,
  max_age_seconds max_age_seconds: Int,
) -> Response {
  let attributes =
    cookie.Attributes(
      max_age: Some(max_age_seconds),
      domain: None,
      path: Some("/"),
      secure: True,
      http_only: True,
      same_site: Some(cookie.Strict),
    )
  let value = wisp.sign_message(request, <<value:utf8>>, crypto.Sha512)

  response.set_cookie(response_, name, value, attributes)
}

fn to_non_negative_int(number: Int) -> Int {
  case number {
    _ if number > 0 -> number
    _ -> 0
  }
}
