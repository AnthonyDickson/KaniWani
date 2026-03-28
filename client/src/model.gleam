import gleam/option.{type Option, None}

import groceries.{type GroceryItem}

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
  LogInPage
}

pub fn empty_home_page_model() -> Model {
  HomePage(items: [], new_item: "", loading: True, saving: False, error: None)
}
