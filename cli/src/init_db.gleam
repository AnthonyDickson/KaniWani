//// Initialises the application database with all the tables and content.
//// Expects a set of SQL files to exist.

import filepath
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import simplifile
import sqlight

const create_table_sql_filenames = [
  "create_password_table.sql",
  "create_grocery_table.sql",
  "create_vocabulary_table.sql",
  "create_lesson_cursor_table.sql",
  "create_lesson_queue_table.sql",
  "create_review_table.sql",
]

const hsk_vocab_sql_filenames = [
  "insert_hsk1_vocabulary.sql",
  "insert_hsk2_vocabulary.sql",
  "insert_hsk3_vocabulary.sql",
  "insert_hsk4_vocabulary.sql",
  "insert_hsk5_vocabulary.sql",
  "insert_hsk6_vocabulary.sql",
]

type Error {
  SQLightError(sqlight.Error)
  SimplifileError(String)
}

/// Initialises the application database with all the tables and content.
/// **Caution**: This function will wipe any existing data from the database.
pub fn init_db(sql_path: String, output_db_path: String) -> Nil {
  let start = timestamp.system_time()
  use connection <- sqlight.with_connection(output_db_path)
  let result = {
    use create_table_queries <- result.try(load_files(
      sql_path,
      create_table_sql_filenames,
    ))

    use insert_hsk_vocab_queries <- result.try(load_files(
      sql_path,
      hsk_vocab_sql_filenames,
    ))

    // Join all queries so they are all executed in a single transaction.
    // sqlight does not seem to allow you to control transactions manually, so
    // we must rely on implicit behaviour.
    let all_queries =
      string.join(create_table_queries, with: "\n")
      <> string.join(insert_hsk_vocab_queries, with: "\n")

    sqlight.exec(all_queries, on: connection) |> result.map_error(SQLightError)
  }

  let elapsed = timestamp.difference(start, timestamp.system_time())
  io.println(
    "Completed in "
    <> elapsed |> duration.to_milliseconds |> int.to_string
    <> "ms",
  )

  case result {
    Ok(Nil) -> io.println("SUCCESS: Initialised database")
    Error(error) ->
      io.println_error(
        "ERROR: Could not initialise database: " <> string.inspect(error),
      )
  }
}

fn load_files(
  sql_path: String,
  filenames: List(String),
) -> Result(List(String), Error) {
  let read_file = fn(path) {
    simplifile.read(path)
    |> result.map_error(fn(error) {
      SimplifileError(string.inspect(error) <> ": " <> path)
    })
  }

  list.map(filenames, filepath.join(sql_path, _))
  |> list.try_map(with: read_file)
}
