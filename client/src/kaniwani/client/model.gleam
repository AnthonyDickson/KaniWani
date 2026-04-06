import gleam/option.{type Option, None}
import kaniwani/client/route.{type Route}
import kaniwani/shared/groceries.{type GroceryItem}
import kaniwani/shared/lesson.{type Lesson}

pub type Model {
  HomePage(
    items: List(GroceryItem),
    new_item: String,
    loading: Bool,
    saving: Bool,
    error: Option(String),
  )
  LessonPage(List(Lesson))
  NotFoundPage
  CheckingAuth(redirect_to: Route)
  LogInPage(
    /// The password entered in the log in form
    password: String,
    show_password: Bool,
    error: Option(String),
  )
}

pub fn empty_home_page_model() -> Model {
  HomePage(items: [], new_item: "", loading: True, saving: False, error: None)
}

pub fn empty_login_page_model() -> Model {
  LogInPage(password: "", show_password: False, error: None)
}
