import gleam/uri.{type Uri}

pub type Route {
  Home
  Foo
  Lesson
  LogIn
  LogOut
  NotFound
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] -> Home
    ["foo"] -> Foo
    ["lesson"] -> Lesson
    ["log_in"] -> LogIn
    ["log_out"] -> LogOut
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
    Lesson -> "Lessons"
    LogIn -> "Log In"
    LogOut -> "Log Out"
    NotFound -> "Page Not Found"
  }
}

pub fn to_path_string(route: Route) -> String {
  case route {
    Home -> "/"
    Foo -> "/foo"
    Lesson -> "/lesson"
    LogIn -> "/log_in"
    LogOut -> "/log_out"
    NotFound -> "#"
  }
}
