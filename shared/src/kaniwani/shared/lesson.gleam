import gleam/dynamic/decode.{type Decoder}
import gleam/json
import kaniwani/shared/hsk_level.{type HskLevel}

pub type Lesson {
  Lesson(
    id: Int,
    hsk_level: HskLevel,
    hans: String,
    hant: String,
    pinyin_input: String,
    pinyin_display: String,
    definition: String,
  )
}

pub fn to_json(lesson: Lesson) -> json.Json {
  let Lesson(
    id:,
    hsk_level:,
    hans:,
    hant:,
    pinyin_input:,
    pinyin_display:,
    definition:,
  ) = lesson
  json.object([
    #("id", json.int(id)),
    #("hsk_level", hsk_level.to_json(hsk_level)),
    #("hans", json.string(hans)),
    #("hant", json.string(hant)),
    #("pinyin_input", json.string(pinyin_input)),
    #("pinyin_display", json.string(pinyin_display)),
    #("definition", json.string(definition)),
  ])
}

pub fn decoder() -> Decoder(Lesson) {
  use id <- decode.field("id", decode.int)
  use hsk_level <- decode.field("hsk_level", hsk_level.decoder())
  use hans <- decode.field("hans", decode.string)
  use hant <- decode.field("hant", decode.string)
  use pinyin_input <- decode.field("pinyin_input", decode.string)
  use pinyin_display <- decode.field("pinyin_display", decode.string)
  use definition <- decode.field("definition", decode.string)
  decode.success(Lesson(
    id:,
    hsk_level:,
    hans:,
    hant:,
    pinyin_input:,
    pinyin_display:,
    definition:,
  ))
}
