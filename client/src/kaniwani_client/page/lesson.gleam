import gleam/io
import gleam/string
import kaniwani/lesson.{type Lesson}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import model.{type Model, LessonPage}
import msg.{type LessonMsg, type Msg, UserNavigatedToLessonPage}
import navbar
import route

pub fn update(model: Model, msg: LessonMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LessonPage([]), UserNavigatedToLessonPage -> {
      // TODO: load lessons
      #(model, effect.none())
    }

    _, _ -> {
      io.println_error(
        "Unhandled model and msg combination: "
        <> string.inspect(model)
        <> " and "
        <> string.inspect(msg),
      )
      #(model, effect.none())
    }
  }
}

pub fn view(_lessons: List(Lesson)) -> Element(Msg) {
  html.div([], [navbar.view(route.Lesson), html.main([], [html.text("TODO")])])
}

fn view_lessons() {
  todo
}

fn view_no_lessons() {
  todo
}
