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
    One -> json.int(1)
    Two -> json.int(2)
    Three -> json.int(3)
    Four -> json.int(4)
    Five -> json.int(5)
    Six -> json.int(6)
  }
}

pub fn decoder() -> decode.Decoder(HskLevel) {
  use variant <- decode.then(decode.int)
  case variant {
    1 -> decode.success(One)
    2 -> decode.success(Two)
    3 -> decode.success(Three)
    4 -> decode.success(Four)
    5 -> decode.success(Five)
    6 -> decode.success(Six)
    _ -> decode.failure(One, "HskLevel")
  }
}
