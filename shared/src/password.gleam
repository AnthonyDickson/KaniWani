import gleam/dynamic/decode
import gleam/json

pub fn password_decoder() -> decode.Decoder(String) {
  use password <- decode.field("password", decode.string)
  decode.success(password)
}

pub fn password_to_json(password: String) -> json.Json {
  json.object([#("password", json.string(password))])
}
