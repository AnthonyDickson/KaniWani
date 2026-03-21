import gleam/bool
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/http/cookie
import gleam/http/response
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/otp/actor.{type Next, type StartError, type Started}
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

import wisp.{type Request, type Response, Signed}
import youid/uuid

const cleanup_sessions_interval_ms: Int = 60_000

const get_session_timeout_ms: Int = 1000

const idle_timeout_minutes: Int = 15

const init_session_store_timeout_ms: Int = 1000

const max_session_age_hours: Int = 24

const session_cookie_name: String = "kaniwani_session"

const status_unauthorised: Int = 401

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
  ClearExpiredSessions
}

type State {
  State(self: SessionStore, sessions: Dict(SessionId, Session))
}

fn handle_message(state: State, message: Message) -> Next(State, Message) {
  let State(self:, sessions:) = state

  case message {
    Set(session) ->
      actor.continue(State(
        self:,
        sessions: dict.insert(into: sessions, for: session.id, insert: session),
      ))

    Get(reply_with: client, id:) -> {
      process.send(client, dict.get(sessions, id) |> option.from_result)
      actor.continue(state)
    }

    Delete(id) ->
      actor.continue(State(
        self:,
        sessions: dict.delete(from: sessions, delete: id),
      ))
    ClearExpiredSessions -> {
      process.send_after(
        self,
        cleanup_sessions_interval_ms,
        ClearExpiredSessions,
      )

      let now = timestamp.system_time()

      actor.continue(State(
        self:,
        sessions: dict.filter(sessions, keeping: fn(_id, session) {
          !is_expired(session, now)
        }),
      ))
    }
  }
}

pub fn start_store() -> Result(Started(Subject(Message)), StartError) {
  actor.new_with_initialiser(init_session_store_timeout_ms, fn(self) {
    process.send_after(self, cleanup_sessions_interval_ms, ClearExpiredSessions)
    let initial_state = State(self:, sessions: dict.new())

    Ok(
      actor.initialised(initial_state)
      |> actor.returning(self),
    )
  })
  |> actor.on_message(handle_message)
  |> actor.start
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
  process.call(session_store, waiting: get_session_timeout_ms, sending: Get(
    _,
    id,
  ))
}

fn set(session_store: SessionStore, session: Session) -> Nil {
  process.send(session_store, Set(session))
}

fn delete(session_store: Subject(Message), id: SessionId) -> Nil {
  process.send(session_store, Delete(id))
}

//----------------------------------------------------------------------------//
// Session Cookies
//----------------------------------------------------------------------------//

pub fn set_session_cookie(
  session: Session,
  req: Request,
  response: Response,
) -> Response {
  set_cookie(
    response:,
    request: req,
    name: session_cookie_name,
    value: session.id,
    max_age_seconds: max_session_age_hours * 60 * 60,
  )
}

pub fn require_valid_session(
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
  case get_session_id_from_cookie(req) {
    Some(session_id) -> delete(session_store, session_id)
    None -> Nil
  }
}

/// Extend the expiry of a session.
/// 
/// Intended to be used as middleware.
pub fn extend_session(
  session_store: SessionStore,
  req: Request,
  now: Timestamp,
  next: fn() -> Response,
) -> Response {
  let session =
    get_session_id_from_cookie(req)
    |> option.then(get(session_store, _))

  case session {
    Some(session) -> {
      use <- bool.guard(when: is_expired(session, now), return: Nil)
      let session = extend(session, from: now)
      set(session_store, session)
    }
    None -> Nil
  }

  next()
}

fn has_valid_session_cookie(
  req: Request,
  session_store: SessionStore,
  now: Timestamp,
) -> Bool {
  get_session_id_from_cookie(req)
  |> option.then(get(session_store, _))
  |> option.map(fn(session) { !is_expired(session, now) })
  |> option.unwrap(False)
}

fn get_session_id_from_cookie(req: Request) -> Option(SessionId) {
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
