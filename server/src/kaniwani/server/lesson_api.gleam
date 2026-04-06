import gleam/http/response.{type Response}
import gleam/json
import gleam/string
import gleam/time/timestamp
import kaniwani/server/lesson_store.{type LessonStore}
import kaniwani/server/logging
import kaniwani/shared/lesson_queue
import wisp

pub fn handle_get_lessons(store: LessonStore) -> Response(wisp.Body) {
  case lesson_store.get_queue(store) {
    Ok(queue) ->
      wisp.ok()
      |> wisp.json_body(
        lesson_queue.LessonQueue(lessons: queue)
        |> lesson_queue.to_json
        |> json.to_string,
      )

    Error(error) -> {
      logging.error(
        when: timestamp.system_time(),
        scope: "GET api/lessons",
        what: string.inspect(error),
      )
      wisp.json_response(
        json.object([#("error", json.string("Could not get lesson queue"))])
          |> json.to_string,
        500,
      )
    }
  }
}
