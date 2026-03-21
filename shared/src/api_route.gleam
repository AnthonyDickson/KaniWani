import gleam/option.{None, Some}
import gleam/string

pub type ApiRoute {
  Groceries
  Register
  Session
  SessionStatus
}

pub fn from_path_segments(path: List(String)) -> option.Option(ApiRoute) {
  case path {
    ["api", "groceries"] -> Some(Groceries)
    ["api", "register"] -> Some(Register)
    ["api", "session"] -> Some(Session)
    ["api", "session", "status"] -> Some(SessionStatus)
    _ -> None
  }
}

pub fn to_path_segments(route: ApiRoute) -> List(String) {
  let path = case route {
    Groceries -> ["groceries"]
    Register -> ["register"]
    Session -> ["session"]
    SessionStatus -> ["session", "status"]
  }

  ["api", ..path]
}

pub fn to_string(route: ApiRoute) -> String {
  "/"
  <> route
  |> to_path_segments
  |> string.join("/")
}
