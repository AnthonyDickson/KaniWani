import gleam/option.{type Option, None}

import groceries.{type GroceryItem}
import route.{type Route}

pub type Model {
  HomePage(
    items: List(GroceryItem),
    new_item: String,
    loading: Bool,
    saving: Bool,
    error: Option(String),
  )
  FooPage
  NotFoundPage
  CheckingAuth
  LoggedOut(
    route: Route,
    /// The password entered in the log in or registration form
    password: String,
    log_in_error: Option(String),
    registration_error: Option(String),
  )
}

pub fn empty_home_page_model() -> Model {
  HomePage(items: [], new_item: "", loading: True, saving: False, error: None)
}

pub fn empty_logged_out_model(route: Route) -> Model {
  LoggedOut(route, password: "", log_in_error: None, registration_error: None)
}
