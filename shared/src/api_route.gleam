import gleam/option.{None, Some}

pub type ApiRoute {
  Index
  Groceries
  Register
  Session
  OAuthLogin
  OAuthCallback
}

pub fn from_path_segments(path: List(String)) -> option.Option(ApiRoute) {
  case path {
    [] -> Some(Index)
    ["api", "groceries"] -> Some(Groceries)
    ["api", "register"] -> Some(Register)
    ["api", "session"] -> Some(Session)
    ["api", "oauth", "login"] -> Some(OAuthLogin)
    ["api", "oauth", "callback"] -> Some(OAuthCallback)
    _ -> None
  }
}

pub fn to_string(route: ApiRoute) -> String {
  case route {
    Index -> "/"
    Groceries -> "/api/groceries"
    Register -> "/api/register"
    Session -> "/api/session"
    OAuthLogin -> "/api/oauth/login"
    OAuthCallback -> "/api/oauth/callback"
  }
}
