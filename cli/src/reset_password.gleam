import argus.{type Hashes}
import gleam/dynamic/decode
import gleam/erlang/charlist.{type Charlist}
import gleam/io
import gleam/result
import gleam/string
import gzxcvbn.{type Feedback, type Options}
import gzxcvbn/common
import gzxcvbn/en
import sqlight.{type Connection}

const minimum_password_score = gzxcvbn.SomewhatGuessable

type ReadPasswordError {
  Eof
  IoError
}

type Error {
  ReadPasswordFailed(ReadPasswordError)
  HashingFailed(argus.HashError)
  SQLiteQueryFailed(sqlight.Error)
}

pub fn reset_password(db_path: String) -> Nil {
  let result = {
    use password <- result.try(get_password_loop(get_gzxcvbn_opts()))
    use password_hash <- result.try(hash_password(password))
    use connection <- sqlight.with_connection(db_path)
    write_password_hash(connection, password_hash.encoded_hash)
  }

  case result {
    Ok(Nil) -> io.println("SUCCESS: Password updated")
    Error(ReadPasswordFailed(Eof)) -> Nil
    Error(ReadPasswordFailed(IoError)) ->
      io.println_error("ERROR: Could not read password")
    Error(error) ->
      io.println_error(
        "ERROR: Could not set password: " <> string.inspect(error),
      )
  }
}

fn get_gzxcvbn_opts() -> Options {
  gzxcvbn.options()
  |> gzxcvbn.with_dictionaries(common.dictionaries())
  |> gzxcvbn.with_dictionaries(en.dictionaries())
  |> gzxcvbn.with_graphs(common.graphs())
  |> gzxcvbn.build()
}

fn get_password_loop(gzxcvbn_opts: Options) -> Result(String, Error) {
  io.print("Enter a password: ")
  use password <- result.try(get_password())

  case check_password_strength(password, gzxcvbn_opts) {
    Ok(password) -> Ok(password)
    Error(gzxcvbn.Feedback(warning:, suggestions:)) -> {
      io.println_error(
        "Password is too weak, please read the hints below and try again.",
      )
      io.println_error(warning)
      io.println(string.join(suggestions, with: "\n"))
      // For spacing between the above paragraph and the next prompt
      io.println("")
      get_password_loop(gzxcvbn_opts)
    }
  }
}

/// Read a string from the terminal, but hide the user's input.
fn get_password() -> Result(String, Error) {
  get_password_erlang()
  |> result.map(charlist.to_string)
  |> result.map_error(ReadPasswordFailed)
}

@external(erlang, "reset_password_ffi", "get_password")
fn get_password_erlang() -> Result(Charlist, ReadPasswordError)

/// Returns `Ok(password)` if the password is strong enough, or the feedback otherwise.
fn check_password_strength(
  password: String,
  options: Options,
) -> Result(String, Feedback) {
  let result = gzxcvbn.check(password, options)
  let score_int = gzxcvbn.score_to_int(result.score)
  let threshold_score = gzxcvbn.score_to_int(minimum_password_score)

  case score_int >= threshold_score {
    True -> Ok(password)
    False -> Error(result.feedback)
  }
}

fn hash_password(password: String) -> Result(Hashes, Error) {
  argus.hasher()
  |> argus.algorithm(argus.Argon2id)
  |> argus.time_cost(3)
  // 32 mebibytes
  |> argus.memory_cost(32_768)
  |> argus.parallelism(1)
  |> argus.hash_length(32)
  |> argus.hash(password, argus.gen_salt())
  |> result.map_error(HashingFailed)
}

fn write_password_hash(
  db_connection: Connection,
  password_hash: String,
) -> Result(Nil, Error) {
  let sql =
    "INSERT INTO password (id, password_hash) VALUES (?, ?) 
       ON CONFLICT (id) DO UPDATE SET
         password_hash = excluded.password_hash;"

  sqlight.query(
    sql,
    on: db_connection,
    with: [sqlight.int(0), sqlight.text(password_hash)],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_list_of_nil) { Nil })
  |> result.map_error(SQLiteQueryFailed)
}
