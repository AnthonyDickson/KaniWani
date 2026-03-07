import gleam/option.{type Option, None}

import groceries.{type GroceryItem}
import route.{type Route}

pub type Model {
  Authenticated(
    route: Route,
    items: List(GroceryItem),
    new_item: String,
    saving: Bool,
    error: Option(String),
  )
  LoadingPage(show: Route, next: Route)
  CheckingAuth(Route)
  LoggedOut(
    route: Route,
    /// The password entered in the log in or registration form
    password: String,
    log_in_error: Option(String),
    registration_error: Option(String),
  )
}

pub fn empty_logged_out(route: Route) -> Model {
  LoggedOut(route, password: "", log_in_error: None, registration_error: None)
}
