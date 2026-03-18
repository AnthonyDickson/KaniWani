import gleam/dynamic/decode
import gleam/result
import gleam/string

import argus
import gzxcvbn.{type Options}
import sqlight.{type Connection, type Error, ConstraintPrimarykey, SqlightError}
import wisp.{type Request, type Response}

import password

type RegistrationError {
  WeakPassword
  InvalidJson
  HashingFailed
  StorageFailed(Error)
  PasswordExists
}

pub fn handle_registration(
  req: Request,
  db_connection: Connection,
  gzxcvbn_opts: Options,
) -> Response {
  use json <- wisp.require_json(req)

  let outcome = {
    use raw_password <- result.try(
      decode.run(json, password.password_decoder())
      |> result.replace_error(InvalidJson),
    )

    use password <- result.try(
      password.check_password_strength(raw_password, gzxcvbn_opts)
      |> result.replace_error(WeakPassword),
    )

    use password_hash <- result.try(
      hash_password(password)
      |> result.replace_error(HashingFailed),
    )

    write_password_hash(db_connection, password_hash.encoded_hash)
  }

  case outcome {
    Ok(_) -> wisp.no_content()
    Error(InvalidJson) -> wisp.bad_request("Invalid JSON")
    Error(WeakPassword) -> wisp.bad_request("Weak Password")
    Error(PasswordExists) ->
      wisp.response(409)
      |> wisp.html_body("Password already exists, sign in instead")
    Error(error) -> {
      wisp.log_error(string.inspect(error))
      wisp.internal_server_error()
    }
  }
}

fn hash_password(password) {
  argus.hasher()
  |> argus.algorithm(argus.Argon2id)
  |> argus.time_cost(3)
  // 32 mebibytes
  |> argus.memory_cost(32_768)
  |> argus.parallelism(1)
  |> argus.hash_length(32)
  |> argus.hash(password, argus.gen_salt())
}

fn write_password_hash(
  db_connection: Connection,
  password_hash: String,
) -> Result(Nil, RegistrationError) {
  let sql = "INSERT INTO password (id, password_hash) VALUES (?, ?)"
  let result =
    sqlight.query(
      sql,
      on: db_connection,
      with: [sqlight.int(0), sqlight.text(password_hash)],
      expecting: decode.success(Nil),
    )

  case result {
    Ok(_) -> Ok(Nil)
    Error(SqlightError(code: ConstraintPrimarykey, message: _, offset: -1)) ->
      Error(PasswordExists)
    Error(error) -> Error(StorageFailed(error))
  }
}
