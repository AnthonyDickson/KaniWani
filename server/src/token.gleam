import gleam/crypto
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}

import wisp.{type Request, type Response}

const auth_token_name = "kaniwani_token"

const auth_cookie_max_age = 300

const status_unauthorised = 401

/// The app is designed around one user, so this will do ¯\_(ツ)_/¯
const user_id = 1

pub opaque type Token {
  Token(user_id: Int)
}

pub fn new() -> Token {
  Token(user_id:)
}

pub fn to_response(token: Token, req: Request) -> Response {
  token
  |> to_json()
  |> json.to_string
  |> set_cookie(wisp.no_content(), req, auth_token_name, _, auth_cookie_max_age)
}

pub fn require_valid_token(req: Request, next: fn() -> Response) -> Response {
  case has_valid_token(req) {
    False -> wisp.response(status_unauthorised)
    True -> next()
  }
}

pub fn handle_validate_token(req: Request) -> Response {
  case has_valid_token(req) {
    True -> wisp.no_content()
    False -> wisp.response(status_unauthorised)
  }
}

pub fn handle_delete_token(req: Request) -> Response {
  set_cookie(wisp.no_content(), req, auth_token_name, "", 0)
}

fn to_json(token: Token) {
  json.object([
    #("user_id", json.int(token.user_id)),
  ])
}

fn has_valid_token(req: Request) -> Bool {
  case wisp.get_cookie(req, auth_token_name, wisp.Signed) {
    Ok(cookie) -> {
      cookie == Token(user_id) |> to_json |> json.to_string
    }
    Error(_) -> False
  }
}

fn set_cookie(
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
