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

pub fn to_int(hsk_level: HskLevel) -> Int {
  case hsk_level {
    One -> 1
    Two -> 2
    Three -> 3
    Four -> 4
    Five -> 5
    Six -> 6
  }
}

pub fn to_json(hsk_level: HskLevel) -> json.Json {
  hsk_level |> to_int |> json.int
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
