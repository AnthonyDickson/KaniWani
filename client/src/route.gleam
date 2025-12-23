import gleam/option
import gleam/uri.{type Uri}

pub type Route {
  Home
  Foo
  NotFound
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] -> Home
    ["foo"] -> Foo
    _ -> NotFound
  }
}

pub fn to_page_title(route: Route) -> String {
  "KaniWani / " <> to_page_name(route)
}

pub fn to_page_name(route: Route) -> String {
  case route {
    Home -> "Home"
    Foo -> "Foo"
    NotFound -> "Page Not Found"
  }
}

pub fn to_path_string(route: Route) -> option.Option(String) {
  case route {
    Home -> option.Some("/")
    Foo -> option.Some("/foo")
    NotFound -> option.None
  }
}
