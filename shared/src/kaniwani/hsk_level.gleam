import gleam/dynamic/decode
import gleam/json

pub type HskLevel {
  One
  Two
  Three
  Four
  Five
  Six
}

pub fn to_json(hsk_level: HskLevel) -> json.Json {
  case hsk_level {
    One -> json.string("one")
    Two -> json.string("two")
    Three -> json.string("three")
    Four -> json.string("four")
    Five -> json.string("five")
    Six -> json.string("six")
  }
}

pub fn decoder() -> decode.Decoder(HskLevel) {
  use variant <- decode.then(decode.string)
  case variant {
    "one" -> decode.success(One)
    "two" -> decode.success(Two)
    "three" -> decode.success(Three)
    "four" -> decode.success(Four)
    "five" -> decode.success(Five)
    "six" -> decode.success(Six)
    _ -> decode.failure(One, "HskLevel")
  }
}
