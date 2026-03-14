import gleam/crypto
import gleam/dynamic/decode.{type DecodeError}
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string

import argus.{type HashError}
import sqlight.{type Connection, type Error as SqlightError}
import wisp.{type Request, type Response}

import password

const auth_token_name = "kaniwani_token"

const auth_cookie_max_age = 300

const status_unauthorised = 401

/// The app is designed around one user, so this will do ¯\_(ツ)_/¯
const user_id = 1

pub type Token {
  Token(user_id: Int)
}

type CreateTokenError {
  DecodeError(List(DecodeError))
  SqlightError(SqlightError)
  HashingError(HashError)
}

pub fn to_json(token: Token) {
  json.object([
    #("user_id", json.int(token.user_id)),
  ])
}

pub fn require_valid_token(req: Request, next: fn() -> Response) -> Response {
  case has_valid_token(req) {
    False -> wisp.response(status_unauthorised)
    True -> next()
  }
}

pub fn handle_create_token(req: Request, db_connection: Connection) -> Response {
  use json <- wisp.require_json(req)
  let outcome = {
    use password <- result.try(
      decode.run(json, password.password_decoder())
      |> result.map_error(DecodeError),
    )
    use password_hash <- result.try(
      read_password_hash(db_connection) |> result.map_error(SqlightError),
    )
    argus.verify(password_hash, password) |> result.map_error(HashingError)
  }

  case outcome {
    Ok(True) ->
      Token(user_id)
      |> to_json()
      |> json.to_string
      |> set_cookie(
        wisp.no_content(),
        req,
        auth_token_name,
        _,
        auth_cookie_max_age,
      )

    Ok(False) -> wisp.response(status_unauthorised)
    Error(error) -> {
      wisp.log_error(error |> string.inspect)
      wisp.internal_server_error()
    }
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

fn read_password_hash(db_connection: Connection) -> Result(String, SqlightError) {
  let sql = "SELECT password_hash FROM password WHERE id = 0"
  let password_hash = {
    use password_hash <- decode.field(0, decode.string)
    decode.success(password_hash)
  }

  use rows <- result.try(sqlight.query(
    sql,
    db_connection,
    with: [],
    expecting: password_hash,
  ))

  case rows {
    [] ->
      Error(sqlight.SqlightError(
        sqlight.Empty,
        "Could not find password hash for user ID = 0",
        -1,
      ))
    [item, ..] -> Ok(item)
  }
}
