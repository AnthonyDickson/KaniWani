import gleam/dynamic/decode
import gleam/json
import kaniwani/shared/lesson.{type Lesson}

pub type LessonQueue {
  LessonQueue(lessons: List(Lesson))
}

pub fn to_json(lesson_queue: LessonQueue) -> json.Json {
  let LessonQueue(lessons:) = lesson_queue
  json.object([
    #("lessons", json.array(lessons, lesson.to_json)),
  ])
}

pub fn decoder() -> decode.Decoder(LessonQueue) {
  use lessons <- decode.field("lessons", decode.list(lesson.decoder()))
  decode.success(LessonQueue(lessons:))
}
