import gleam/float
import gleam/int
import gleam/io
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

pub fn info(
  when timestamp: Timestamp,
  scope scope: String,
  what message: String,
) -> Nil {
  let timestamp_string = timestamp.to_rfc3339(timestamp, duration.hours(12))
  io.println("[" <> timestamp_string <> "][" <> scope <> "] " <> message)
}

pub fn error(
  when timestamp: Timestamp,
  scope scope: String,
  what message: String,
) -> Nil {
  let timestamp_string = timestamp.to_rfc3339(timestamp, duration.hours(12))
  io.println_error("[" <> timestamp_string <> "][" <> scope <> "] " <> message)
}

pub fn elapsed_string_ms(elapsed: duration.Duration) -> String {
  duration.to_seconds(elapsed) *. 1000.0
  |> float.truncate
  |> int.to_string
  <> " ms"
}
