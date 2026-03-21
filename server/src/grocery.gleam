import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string

import sqlight.{type Connection, type Error}
import wisp.{type Request, type Response}

import groceries.{type GroceryItem, GroceryItem}

type SaveGroceriesError {
  DecodeError(List(decode.DecodeError))
  SqlightError(Error)
}

pub fn handle_save_groceries(
  req: Request,
  db_connection: Connection,
) -> Response {
  use json <- wisp.require_json(req)

  let outcome = {
    use items <- result.try(
      decode.run(json, groceries.grocery_list_decoder())
      |> result.map_error(DecodeError),
    )
    write_grocery_items(db_connection, items) |> result.map_error(SqlightError)
  }

  case outcome {
    Ok(Nil) -> wisp.ok()
    Error(DecodeError(_)) -> wisp.bad_request("Request failed")
    Error(SqlightError(_)) -> wisp.internal_server_error()
  }
}

pub fn handle_get_all_groceries(db_connection: Connection) -> Response {
  case read_grocery_items(db_connection) {
    Ok(grocery_list) -> {
      wisp.json_response(
        grocery_list |> groceries.grocery_list_to_json |> json.to_string,
        200,
      )
    }
    Error(error) -> {
      wisp.log_error(error |> string.inspect)
      wisp.internal_server_error()
    }
  }
}

fn write_grocery_items(
  db_connection: Connection,
  items: List(GroceryItem),
) -> Result(Nil, Error) {
  let placeholders =
    list.map(items, fn(_) { "(?, ?)" })
    |> string.join(",")

  let sql =
    "INSERT INTO grocery (name, quantity) VALUES "
    <> placeholders
    <> "ON CONFLICT(name) DO UPDATE SET quantity = excluded.quantity"

  let params =
    list.flat_map(items, fn(item) {
      let GroceryItem(name:, quantity:) = item
      [sqlight.text(name), sqlight.int(quantity)]
    })

  sqlight.query(
    sql,
    on: db_connection,
    with: params,
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}

fn read_grocery_items(
  db_connection: Connection,
) -> Result(List(GroceryItem), Error) {
  let sql = "SELECT name, quantity FROM grocery"
  let grocery_item = {
    use name <- decode.field(0, decode.string)
    use quantity <- decode.field(1, decode.int)
    decode.success(GroceryItem(name:, quantity:))
  }
  sqlight.query(sql, on: db_connection, with: [], expecting: grocery_item)
}
