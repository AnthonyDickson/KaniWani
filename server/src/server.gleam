import gleam/erlang/process
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/option.{Some}
import gleam/result

import envoy
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import sqlight.{type Connection, type Error}
import wisp.{type Request, type Response}
import wisp/wisp_mist

import api_route.{Groceries, Register, Token, TokenStatus}
import grocery
import registration
import token

const static_file_path = "/static"

const javascript_bundle_path = static_file_path <> "/client.js"

const css_bundle_path = static_file_path <> "/client.css"

pub fn main() -> Nil {
  wisp.configure_logger()
  let assert Ok(secret_key_base) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(database_path) = envoy.get("DATABASE_PATH")
  let host = envoy.get("HOST") |> result.unwrap("localhost")
  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(3000)

  let assert Ok(db) = setup_database(database_path)

  let assert Ok(priv_directory) = wisp.priv_directory("server")
  let static_directory = priv_directory <> "/static"

  let assert Ok(_) =
    handle_request(db, static_directory, _)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind(host)
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}

// Request Handlers -----------------------------------------------------------

fn handle_request(
  db_connection: Connection,
  static_directory: String,
  req: Request,
) -> Response {
  use req <- app_middleware(req, static_directory)

  case req.method, wisp.path_segments(req) |> api_route.from_path_segments {
    Get, Some(Groceries) -> grocery.handle_get_all_groceries(req, db_connection)
    Post, Some(Groceries) -> grocery.handle_save_groceries(req, db_connection)
    Post, Some(Register) -> registration.handle_registration(req, db_connection)
    Post, Some(Token) -> token.handle_create_token(req, db_connection)
    Delete, Some(Token) -> token.handle_delete_token(req)
    Get, Some(TokenStatus) -> token.handle_validate_token(req)
    Get, _ -> serve_index()
    _, _ -> wisp.not_found()
  }
}

fn app_middleware(
  req: Request,
  static_directory: String,
  next: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: static_file_path, from: static_directory)

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

fn setup_database(database_path: String) -> Result(Connection, Error) {
  use connection <- result.try(sqlight.open(database_path))

  use _ <- result.try(sqlight.exec(
    "CREATE TABLE IF NOT EXISTS password (id INTEGER PRIMARY KEY, password_hash TEXT)",
    connection,
  ))
  use _ <- result.try(sqlight.exec(
    "CREATE TABLE IF NOT EXISTS grocery (id INTEGER PRIMARY KEY, name TEXT UNIQUE, quantity INTEGER)",
    connection,
  ))

  Ok(connection)
}
