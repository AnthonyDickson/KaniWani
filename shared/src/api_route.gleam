import gleam/option
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
    ["api", "groceries"] -> option.Some(Groceries)
    ["api", "register"] -> option.Some(Register)
    ["api", "token"] -> option.Some(Token)
    ["api", "token", "status"] -> option.Some(TokenStatus)
    _ -> option.None
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
