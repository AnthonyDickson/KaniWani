import gleam/bool
import gleam/crypto
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Delete, Get, Post}
import gleam/http/cookie
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string

import argus.{type HashError, type Hashes}
import envoy
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import storail
import wisp.{type Request, type Response}
import wisp/wisp_mist

import api_route.{Groceries, Register, Token, TokenStatus}
import groceries.{type GroceryItem}
import password
import token

const static_file_path = "/static"

const javascript_bundle_path = static_file_path <> "/client.js"

const css_bundle_path = static_file_path <> "/client.css"

const database_storage_path = "./data"

const auth_token_name = "kaniwani_token"

const auth_cookie_max_age = 300

const status_unauthorised = 401

const min_password_length = 16

/// The app is designed around one user, so this will do ¯\_(ツ)_/¯
const user_id = 1

pub fn main() -> Nil {
  wisp.configure_logger()
  let assert Ok(secret_key_base) = envoy.get("SECRET_KEY_BASE")
  let host = envoy.get("HOST") |> result.unwrap("localhost")
  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(3000)

  let assert Ok(db) = setup_database()

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
  db: Database,
  static_directory: String,
  req: Request,
) -> Response {
  use req <- app_middleware(req, static_directory)

  case req.method, wisp.path_segments(req) |> api_route.from_path_segments {
    Get, Some(Groceries) -> handle_get_all_groceries(req, db.grocery_list)
    Post, Some(Groceries) -> handle_save_groceries(db.grocery_list, req)
    Post, Some(Register) -> handle_registration(req, db.password)
    Post, Some(Token) -> handle_create_token(req, db.password)
    Delete, Some(Token) -> handle_delete_token(req)
    Get, Some(TokenStatus) -> handle_validate_token(req)
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

fn require_valid_token(req: Request, next: fn() -> Response) -> Response {
  case has_valid_token(req) {
    False -> wisp.response(status_unauthorised)
    True -> next()
  }
}

fn handle_save_groceries(
  db: storail.Collection(List(GroceryItem)),
  req: Request,
) -> Response {
  use <- require_valid_token(req)
  use json <- wisp.require_json(req)

  case decode.run(json, groceries.grocery_list_decoder()) {
    Ok(items) ->
      case save_items_to_db(db, items) {
        Ok(_) -> wisp.ok()
        Error(_) -> wisp.internal_server_error()
      }
    Error(_) -> wisp.bad_request("Request failed")
  }
}

fn handle_get_all_groceries(
  req: Request,
  db: storail.Collection(List(GroceryItem)),
) -> Response {
  use <- require_valid_token(req)
  let items = fetch_items_from_db(db)
  let json = groceries.grocery_list_to_json(items)
  wisp.json_response(json.to_string(json), 200)
}

fn fetch_items_from_db(
  db: storail.Collection(List(GroceryItem)),
) -> List(GroceryItem) {
  storail.read(grocery_list_key(db))
  |> result.unwrap([])
}

fn handle_validate_token(req: Request) -> Response {
  case has_valid_token(req) {
    True -> wisp.no_content()
    False -> wisp.response(status_unauthorised)
  }
}

fn has_valid_token(req: Request) -> Bool {
  case wisp.get_cookie(req, auth_token_name, wisp.Signed) {
    Ok(cookie) -> {
      cookie == token.Token(user_id) |> token.to_json |> json.to_string
    }
    Error(_) -> False
  }
}

fn handle_registration(
  req: Request,
  password_db: storail.Collection(String),
) -> Response {
  use json <- wisp.require_json(req)

  case register_password(json, password_db) {
    Ok(_) -> wisp.no_content()
    Error(InvalidJson) -> wisp.bad_request("Invalid JSON")
    Error(WeakPassword) -> wisp.bad_request("Weak Password")
    Error(_) -> wisp.internal_server_error()
  }
}

type RegistrationError {
  WeakPassword
  InvalidJson
  HashingFailed
  StorageFailed
}

fn register_password(
  json: dynamic.Dynamic,
  password_db: storail.Collection(String),
) -> Result(Nil, RegistrationError) {
  use password <- result.try(
    decode.run(json, password.password_decoder())
    |> result.map_error(fn(_) { InvalidJson }),
  )

  use <- bool.guard(
    when: string.length(password) < min_password_length,
    return: Error(WeakPassword),
  )

  use password_hash <- result.try(
    hash_password(password)
    |> result.map_error(fn(_) { HashingFailed }),
  )

  storail.write(password_key(password_db), password_hash.encoded_hash)
  |> result.map_error(fn(_) { StorageFailed })
}

fn hash_password(password: String) -> Result(Hashes, HashError) {
  argus.hasher()
  |> argus.algorithm(argus.Argon2id)
  |> argus.time_cost(3)
  // 32 mebibytes
  |> argus.memory_cost(32_768)
  |> argus.parallelism(1)
  |> argus.hash_length(32)
  |> argus.hash(password, argus.gen_salt())
}

fn handle_create_token(
  req: Request,
  password_db: storail.Collection(String),
) -> Response {
  use json <- wisp.require_json(req)
  let password = decode.run(json, password.password_decoder())
  let password_hash = storail.read(password_key(password_db))
  case password, password_hash {
    Ok(password), Ok(password_hash) ->
      case argus.verify(password_hash, password) {
        Ok(True) ->
          token.Token(user_id)
          |> token.to_json()
          |> json.to_string
          |> set_cookie(
            wisp.no_content(),
            req,
            auth_token_name,
            _,
            auth_cookie_max_age,
          )

        Ok(False) -> wisp.response(status_unauthorised)
        Error(_) -> wisp.internal_server_error()
      }
    Error(_), _ -> wisp.bad_request("Invalid json")
    _, Error(_) -> wisp.internal_server_error()
  }
}

fn handle_delete_token(req: Request) -> Response {
  set_cookie(wisp.no_content(), req, auth_token_name, "", 0)
}

pub fn set_cookie(
  response response_: Response,
  request request: Request,
  name name: String,
  value value: String,
  max_age max_age: Int,
) -> Response {
  let attributes =
    cookie.Attributes(
      max_age: Some(max_age),
      domain: None,
      path: Some("/"),
      secure: True,
      http_only: True,
      same_site: Some(cookie.Strict),
    )
  let value = wisp.sign_message(request, <<value:utf8>>, crypto.Sha512)

  response.set_cookie(response_, name, value, attributes)
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

type Database {
  Database(
    grocery_list: storail.Collection(List(GroceryItem)),
    password: storail.Collection(String),
  )
}

fn setup_database() -> Result(Database, Nil) {
  let config = storail.Config(storage_path: database_storage_path)

  let grocery_list =
    storail.Collection(
      name: "grocery_list",
      to_json: groceries.grocery_list_to_json,
      decoder: groceries.grocery_list_decoder(),
      config:,
    )

  let password =
    storail.Collection(
      name: "password",
      to_json: password.password_to_json,
      decoder: password.password_decoder(),
      config:,
    )

  Ok(Database(grocery_list:, password:))
}

fn grocery_list_key(
  db: storail.Collection(List(GroceryItem)),
) -> storail.Key(List(GroceryItem)) {
  storail.key(db, "grocery_list")
}

fn password_key(db: storail.Collection(String)) -> storail.Key(String) {
  storail.key(db, "password")
}

fn save_items_to_db(
  db: storail.Collection(List(GroceryItem)),
  items: List(GroceryItem),
) -> Result(Nil, storail.StorailError) {
  storail.write(grocery_list_key(db), items)
}
