import gleam/option.{None, Some}
import gleam/string

pub type ApiRoute {
  Index
  Groceries
  Session
}

pub fn from_path_segments(path: List(String)) -> option.Option(ApiRoute) {
  case path {
    [] -> Some(Index)
    ["api", "groceries"] -> Some(Groceries)
    ["api", "session"] -> Some(Session)
    _ -> None
  }
}

pub fn to_path_segments(route: ApiRoute) -> List(String) {
  case route {
    Index -> []
    Groceries -> ["api", "groceries"]
    Session -> ["api", "session"]
  }
}

pub fn to_string(route: ApiRoute) -> String {
  "/"
  <> route
  |> to_path_segments
  |> string.join("/")
}
