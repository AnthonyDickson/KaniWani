import gleam/option.{type Option, None}

import gzxcvbn.{type Feedback, type Options}

import groceries.{type GroceryItem}
import password

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
  LogInPage(
    /// The password entered in the log in form
    password: String,
    show_password: Bool,
    error: Option(String),
  )
  RegisterPage(
    /// The password entered in the registration form
    password: String,
    show_password: Bool,
    error: Option(RegistrationError),
    gzxcvbn_options: Options,
  )
}

pub type RegistrationError {
  RegistrationMessage(String)
  RegistrationFeedback(Feedback)
}

pub fn empty_home_page_model() -> Model {
  HomePage(items: [], new_item: "", loading: True, saving: False, error: None)
}

pub fn empty_login_page_model() -> Model {
  LogInPage(password: "", show_password: False, error: None)
}

pub fn empty_register_page_model() -> Model {
  RegisterPage(
    password: "",
    show_password: False,
    error: None,
    gzxcvbn_options: password.get_gzxcvbn_opts(),
  )
}
