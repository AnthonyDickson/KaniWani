import gleam/dynamic/decode
import gleam/json

import gzxcvbn.{type Feedback, type Options}
import gzxcvbn/common
import gzxcvbn/en

const minimum_password_score = gzxcvbn.SomewhatGuessable

pub fn password_decoder() -> decode.Decoder(String) {
  use password <- decode.field("password", decode.string)
  decode.success(password)
}

pub fn password_to_json(password: String) -> json.Json {
  json.object([#("password", json.string(password))])
}

pub fn get_gzxcvbn_opts() -> Options {
  gzxcvbn.options()
  |> gzxcvbn.with_dictionaries(common.dictionaries())
  |> gzxcvbn.with_dictionaries(en.dictionaries())
  |> gzxcvbn.with_graphs(common.graphs())
  |> gzxcvbn.build()
}

/// Returns `Ok(password)` if the password is strong enough, or the feedback otherwise.
pub fn check_password_strength(
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
