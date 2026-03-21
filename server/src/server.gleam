import gleam/erlang/process.{type Subject}
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}

import envoy
import gzxcvbn.{type Options}
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import sqlight.{type Connection, type Error}
import wisp.{type Request, type Response}
import wisp/wisp_mist

import api_route.{Groceries, Register, Session, SessionStatus}
import grocery
import log_in
import password
import registration
import session.{type Message, type SessionStore}

const static_file_path = "/static"

const javascript_bundle_path = static_file_path <> "/client.js"

const css_bundle_path = static_file_path <> "/client.css"

type Context {
  Context(
    db_connection: Connection,
    session_store: Subject(Message),
    static_directory: String,
    gzxcvbn_opts: Options,
  )
}

pub fn main() -> Nil {
  wisp.configure_logger()
  let assert Ok(secret_key_base) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(database_path) = envoy.get("DATABASE_PATH")
  let host = envoy.get("HOST") |> result.unwrap("localhost")
  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(3000)

  use session_store <- require_session_store()

  use db_connection <- sqlight.with_connection(database_path)
  let assert Ok(Nil) = setup_database(db_connection)

  let assert Ok(priv_directory) = wisp.priv_directory("server")
  let static_directory = priv_directory <> "/static"

  let ctx =
    Context(
      db_connection:,
      static_directory:,
      session_store:,
      gzxcvbn_opts: password.get_gzxcvbn_opts(),
    )

  let assert Ok(_) =
    handle_request(ctx, _)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind(host)
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}

fn require_session_store(next: fn(SessionStore) -> Nil) {
  case session.start_store() {
    Ok(actor) -> next(actor.data)
    Error(error) -> {
      io.println_error(
        "Could not start session store: " <> string.inspect(error),
      )
      Nil
    }
  }
}

// Request Handlers -----------------------------------------------------------

fn handle_request(ctx: Context, req: Request) -> Response {
  let Context(db_connection:, session_store:, static_directory:, gzxcvbn_opts:) =
    ctx
  let now = timestamp.system_time()
  use req <- app_middleware(req, static_directory, session_store, now)

  case wisp.path_segments(req) |> api_route.from_path_segments, req.method {
    Some(Groceries), Get ->
      grocery.handle_get_all_groceries(req, db_connection, session_store, now)
    Some(Groceries), Post ->
      grocery.handle_save_groceries(req, db_connection, session_store, now)
    Some(Register), Post ->
      registration.handle_registration(req, db_connection, gzxcvbn_opts)
    Some(Session), Post ->
      log_in.handle_log_in(req, db_connection, session_store, now)
    Some(Session), Delete -> session.handle_delete_session(req, session_store)
    Some(SessionStatus), Get ->
      session.handle_validate_session_cookie(req, session_store, now)
    _, Get -> serve_index()
    _, _ -> wisp.not_found()
  }
}

fn app_middleware(
  req: Request,
  static_directory: String,
  session_store: SessionStore,
  now: Timestamp,
  next: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: static_file_path, from: static_directory)
  use <- session.extend_session(session_store, req, now)

  next(req)
}

fn serve_index() -> Response {
  let html =
    html.html([], [
      html.head([], [
        html.title([], "KaniWani"),
        html.script(
          [attribute.type_("module"), attribute.src(javascript_bundle_path)],
          "",
        ),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href(css_bundle_path),
        ]),
      ]),
      html.body([], [html.div([attribute.id("app")], [])]),
    ])

  html
  |> element.to_document_string
  |> wisp.html_response(200)
}

// Database -------------------------------------------------------------------

fn setup_database(db_connection: Connection) -> Result(Nil, Error) {
  use _ <- result.try(sqlight.exec(
    "CREATE TABLE IF NOT EXISTS password (id INTEGER PRIMARY KEY, password_hash TEXT)",
    db_connection,
  ))

  use _ <- result.try(sqlight.exec(
    "CREATE TABLE IF NOT EXISTS grocery (id INTEGER PRIMARY KEY, name TEXT UNIQUE, quantity INTEGER)",
    db_connection,
  ))

  Ok(Nil)
}
