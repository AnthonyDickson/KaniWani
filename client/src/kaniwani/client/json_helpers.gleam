import gleam/json.{type DecodeError}
import gleam/list
import gleam/string

pub fn describe_error(error: DecodeError) -> String {
  "JSON decode error: "
  <> case error {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(bytes) -> bytes
    json.UnexpectedSequence(seq) -> seq
    json.UnableToDecode(decode_errors) ->
      list.map(decode_errors, fn(err) {
        "expected "
        <> err.expected
        <> ", found "
        <> err.found
        <> " at path "
        <> string.join(err.path, "/")
      })
      |> string.join("\n")
  }
}
