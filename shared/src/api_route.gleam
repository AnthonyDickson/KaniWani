import gleam/option.{None, Some}
import gleam/string

pub type ApiRoute {
  Groceries
  Register
  Token
  TokenStatus
}

pub const auth_status = ["api", "auth", "status"]

pub fn from_path_segments(path: List(String)) -> option.Option(ApiRoute) {
  case path {
    ["api", "groceries"] -> Some(Groceries)
    ["api", "register"] -> Some(Register)
    ["api", "token"] -> Some(Token)
    ["api", "token", "status"] -> Some(TokenStatus)
    _ -> None
  }
}

pub fn to_path_segments(route: ApiRoute) -> List(String) {
  let path = case route {
    Groceries -> ["groceries"]
    Register -> ["register"]
    Token -> ["token"]
    TokenStatus -> ["token", "status"]
  }

  ["api", ..path]
}

pub fn to_string(route: ApiRoute) -> String {
  "/"
  <> route
  |> to_path_segments
  |> string.join("/")
}
