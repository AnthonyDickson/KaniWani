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
  LessonPage(LessonPageModel)
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

// Lesson Page State -------------------------------------------------------- //
pub type LessonId =
  Int

pub type LessonCompletion {
  LessonCompletion(lesson_id: LessonId, reading: Bool, meaning: Bool)
}

pub type LessonQuestion {
  Meaning(LessonId)
  Reading(LessonId)
}

pub type LessonPageModel {
  LessonLoading
  LessonInfo(LessonInfoModel)
  LessonQuiz(LessonQuizModel)
  LessonCompleted
}

pub type LessonInfoModel {
  /// `previous` is a queue of the seen lessons in reverse order. The first item
  /// is the lesson to show when navigating backwards.
  /// `next` is a queue of unseen lessons. The first item is the lesson to show
  /// when navigating forwards.
  /// ```gleam
  /// LessonInfoModel(
  ///   previous: [Lesson(id: 3, ..), Lesson(id: 2, ..), Lesson(id: 1, ...)],
  ///   current: Lesson(id: 4, ..),
  ///   next: [Lesson(id: 5, ..), Lesson(id: 6, ..), Lesson(id: 7, ...)],
  /// )
  /// ```
  LessonInfoModel(previous: List(Lesson), current: Lesson, next: List(Lesson))
}

pub type LessonQuizModel {
  LessonQuizModel(
    question_queue: List(LessonQuestion),
    completion: List(LessonCompletion),
    lessons: List(Lesson),
  )
}
