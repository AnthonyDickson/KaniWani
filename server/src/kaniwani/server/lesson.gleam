import gleam/bool
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor.{type Next, type StartError, type Started}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import kaniwani/server/logging
import kaniwani/shared/lesson.{type Lesson}
import sqlight.{type Connection}

const max_queue_size: Int = 10

const init_lesson_store_timeout_ms: Int = 1000

/// 24 hours
const queue_lessons_interval_ms: Int = 86_400_000

const get_queue_timeout_ms: Int = 1000

type LessonQueue =
  List(Lesson)

//----------------------------------------------------------------------------//
// Lesson Store (Actor)
//----------------------------------------------------------------------------//

pub type LessonStore =
  Subject(Message)

pub opaque type Message {
  GetQueue(reply_with: Subject(Result(LessonQueue, sqlight.Error)))
  EnqueueLessons
}

type State {
  State(self: LessonStore, db: Connection)
}

fn handle_message(state: State, message: Message) -> Next(State, Message) {
  let State(self:, db:) = state

  case message {
    GetQueue(reply_with: client) -> handle_get_queue(client, db, state)
    EnqueueLessons -> handle_enqueue_lessons(self, db)
  }
}

pub fn start_store(db: Connection) -> Result(Started(LessonStore), StartError) {
  actor.new_with_initialiser(init_lesson_store_timeout_ms, fn(self) {
    process.send(self, EnqueueLessons)
    let initial_state = State(self:, db:)

    Ok(
      actor.initialised(initial_state)
      |> actor.returning(self),
    )
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

//----------------------------------------------------------------------------//
// Handle GetQueue
//----------------------------------------------------------------------------//

pub fn get_queue(
  lesson_store: LessonStore,
) -> Result(LessonQueue, sqlight.Error) {
  process.call(lesson_store, waiting: get_queue_timeout_ms, sending: GetQueue)
}

fn handle_get_queue(
  client: Subject(Result(List(Lesson), sqlight.Error)),
  db: Connection,
  state: State,
) -> Next(State, Message) {
  process.send(client, fetch_queue(db))
  actor.continue(state)
}

fn fetch_queue(db: Connection) -> Result(LessonQueue, sqlight.Error) {
  let query =
    "SELECT
      vocab.id,
      vocab.hsk_level,
      vocab.hans,
      vocab.hant,
      vocab.pinyin_input,
      vocab.pinyin_display,
      vocab.definition
    FROM lesson_queue 
    INNER JOIN vocab 
    ON lesson_queue.vocab_id = vocab.id;
    "
  sqlight.query(query, on: db, with: [], expecting: lesson.decoder())
}

//----------------------------------------------------------------------------//
// Handle EnqueueLessons
//----------------------------------------------------------------------------//

type EnqueueError {
  SqlightError(sqlight.Error)
  EmptyVocabIdList
}

fn handle_enqueue_lessons(
  self: Subject(Message),
  db: Connection,
) -> Next(State, Message) {
  process.send_after(self, queue_lessons_interval_ms, EnqueueLessons)

  let start = timestamp.system_time()
  let next_run_timestamp =
    timestamp.add(start, duration.milliseconds(queue_lessons_interval_ms))

  let outcome = {
    use queued_count <- result.try(count_queued_lessons(db))
    let enqueue_count = int.max(max_queue_size - queued_count, 0)
    use <- bool.guard(when: enqueue_count <= 0, return: Ok(0))
    use vocab_ids <- result.try(get_next_vocab_ids(db, enqueue_count))
    let queued_at = timestamp.system_time()
    use Nil <- result.try(enqueue_lessons(db, vocab_ids, queued_at))
    Ok(enqueue_count)
  }

  let elapsed = timestamp.difference(start, timestamp.system_time())

  case outcome {
    Ok(enqueue_count) ->
      logging.info(
        when: timestamp.system_time(),
        scope: "EnqueueMessage",
        what: "Enqueued "
          <> int.to_string(enqueue_count)
          <> " lessons in "
          <> logging.elapsed_string_ms(elapsed),
      )
    Error(error) ->
      logging.error(
        when: timestamp.system_time(),
        scope: "EnqueueMessage",
        what: string.inspect(error)
          <> " in "
          <> logging.elapsed_string_ms(elapsed),
      )
  }

  logging.info(
    when: timestamp.system_time(),
    scope: "EnqueueMessage",
    what: "Running again at "
      <> timestamp.to_rfc3339(next_run_timestamp, duration.hours(12)),
  )

  actor.continue(State(self:, db:))
}

fn count_queued_lessons(db: Connection) -> Result(Int, EnqueueError) {
  let query = "SELECT COUNT(*) FROM lesson_queue;"

  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  sqlight.query(query, on: db, with: [], expecting: count_decoder)
  |> result.try(first_row)
  |> result.map_error(SqlightError)
}

fn get_next_vocab_ids(
  db: Connection,
  enqueue_count: Int,
) -> Result(List(Int), EnqueueError) {
  use cursor <- result.try(get_lesson_cursor(db))
  use max_cursor <- result.try(get_max_cursor(db))
  let first = int.min(cursor + 1, max_cursor)
  let last = int.min(first + enqueue_count - 1, max_cursor)
  let vocab_to_enqueue = list.range(from: first, to: last)
  Ok(vocab_to_enqueue)
}

fn get_max_cursor(db: Connection) -> Result(Int, EnqueueError) {
  let query = "SELECT MAX(id) FROM vocabulary;"
  let max_decoder = {
    use max <- decode.field(0, decode.int)
    decode.success(max)
  }

  sqlight.query(query, on: db, with: [], expecting: max_decoder)
  |> result.try(first_row)
  |> result.map_error(SqlightError)
}

/// Add vocabulary items to the lesson queue.
fn enqueue_lessons(
  db: Connection,
  vocab_ids: List(Int),
  queued_at: Timestamp,
) -> Result(Nil, EnqueueError) {
  // This function directly creates the query string with the interpolated values
  // instead of passing parameters since only `sqlight.exec` and not
  // `sqlight.query` supports multiple statements.
  use <- bool.guard(when: vocab_ids == [], return: Ok(Nil))
  use last <- result.try(
    list.last(vocab_ids) |> result.replace_error(EmptyVocabIdList),
  )
  let update_cursor_query =
    "UPDATE lesson_cursor SET last_queued_vocab_id = "
    <> int.to_string(last)
    <> ";"
  let enqueue_lessons_query = build_enqueue_lesson_query(vocab_ids, queued_at)

  let query =
    string.join(
      ["BEGIN;", update_cursor_query, enqueue_lessons_query, "COMMIT;"],
      with: "\n",
    )

  sqlight.exec(query, on: db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(SqlightError)
}

fn build_enqueue_lesson_query(
  vocab_to_enqueue: List(Int),
  queued_at: Timestamp,
) -> String {
  let timestamp = timestamp_to_int(queued_at)
  let params =
    list.map(vocab_to_enqueue, fn(vocab_id) {
      "(" <> int.to_string(vocab_id) <> ", " <> int.to_string(timestamp) <> ")"
    })
  let query = "INSERT INTO lesson_queue (vocab_id, queued_at) VALUES\n"
  query <> string.join(params, with: ",\n") <> ";"
}

/// Get the last queued vocab ID. If there is no entry in the database, zero is
/// returned.
fn get_lesson_cursor(db: Connection) -> Result(Int, EnqueueError) {
  let query = "SELECT last_queued_vocab_id FROM lesson_cursor WHERE id = 1"
  let cursor_decoder = {
    use cursor <- decode.field(0, decode.int)
    decode.success(cursor)
  }

  sqlight.query(query, on: db, with: [], expecting: cursor_decoder)
  |> result.try(fn(rows) { first_row(rows) |> result.or(Ok(0)) })
  |> result.map_error(SqlightError)
}

fn timestamp_to_int(timestamp: Timestamp) -> Int {
  timestamp.to_unix_seconds(timestamp)
  |> float.round
}

fn first_row(rows: List(t)) -> Result(t, sqlight.Error) {
  case rows {
    [row, ..] -> Ok(row)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "Expected at least one row",
        -1,
      ))
  }
}
