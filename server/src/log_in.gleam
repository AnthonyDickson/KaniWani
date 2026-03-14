import gleam/dynamic/decode.{type DecodeError}
import gleam/result
import gleam/string

import argus.{type HashError}
import sqlight.{type Connection, type Error as SqlightError}
import wisp.{type Request, type Response}

import password
import token

const status_unauthorised = 401

type LogInError {
  DecodeError(List(DecodeError))
  SqlightError(SqlightError)
  HashingError(HashError)
  PasswordNotSet
}

pub fn handle_log_in(req: Request, db_connection: Connection) -> Response {
  use json <- wisp.require_json(req)
  let outcome = {
    use password <- result.try(
      decode.run(json, password.password_decoder())
      |> result.map_error(DecodeError),
    )
    use password_hash <- result.try(read_password_hash(db_connection))
    argus.verify(password_hash, password) |> result.map_error(HashingError)
  }

  case outcome {
    Ok(True) -> token.new() |> token.to_response(req)
    Ok(False) -> wisp.response(status_unauthorised)
    Error(PasswordNotSet) -> wisp.not_found()
    Error(error) -> {
      error |> string.inspect |> wisp.log_error
      wisp.internal_server_error()
    }
  }
}

fn read_password_hash(db_connection: Connection) -> Result(String, LogInError) {
  let sql = "SELECT password_hash FROM password WHERE id = 0"
  let password_hash = {
    use password_hash <- decode.field(0, decode.string)
    decode.success(password_hash)
  }

  use rows <- result.try(
    sqlight.query(sql, db_connection, with: [], expecting: password_hash)
    |> result.map_error(SqlightError),
  )

  case rows {
    [] -> Error(PasswordNotSet)
    [item, ..] -> Ok(item)
  }
}
