import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import kaniwani/client/json_helpers
import kaniwani/client/model.{
  type LessonCompletion, type LessonInfoModel, type LessonPageModel,
  type LessonQuestion, type LessonQuizModel, type Model, LessonCompleted,
  LessonCompletion, LessonInfo, LessonInfoModel, LessonLoading, LessonPage,
  LessonQuiz, LessonQuizModel, Meaning, Reading,
}
import kaniwani/client/msg.{
  type LessonMsg, type Msg, ClientLoadedLessons, LessonMsg, UserClickedNextInfo,
  UserClickedPreviousInfo, UserNavigatedToLessonPage,
}
import kaniwani/client/navbar
import kaniwani/client/route
import kaniwani/shared/api_route.{Lesson as LessonApiRoute}
import kaniwani/shared/hsk_level
import kaniwani/shared/lesson.{type Lesson, Lesson}
import kaniwani/shared/lesson_queue.{LessonQueue}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

// Update ------------------------------------------------------------------- //
pub fn update(model: Model, msg: LessonMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LessonPage(LessonLoading), UserNavigatedToLessonPage -> {
      #(model, fetch_lessons() |> effect.map(LessonMsg))
    }

    LessonPage(LessonLoading), ClientLoadedLessons(Ok(response)) -> {
      case json.parse(response.body, lesson_queue.decoder()) {
        Ok(LessonQueue(lessons)) -> #(
          LessonPage(init_state(lessons)),
          effect.none(),
        )
        Error(error) -> {
          // TODO: Display error in page
          json_helpers.describe_error(error) |> io.println_error
          #(model, effect.none())
        }
      }
    }

    LessonPage(LessonInfo(lesson_info_model)), UserClickedPreviousInfo -> #(
      previous_lesson_info(lesson_info_model) |> LessonInfo |> LessonPage,
      effect.none(),
    )

    LessonPage(LessonInfo(lesson_info_model)), UserClickedNextInfo ->
      case list.is_empty(lesson_info_model.next) {
        True -> #(
          transition_to_quiz(lesson_info_model) |> LessonPage,
          effect.none(),
        )
        False -> #(
          next_lesson_info(lesson_info_model) |> LessonInfo |> LessonPage,
          effect.none(),
        )
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

fn init_state(lessons: List(Lesson)) -> LessonPageModel {
  case lessons {
    [] -> LessonCompleted
    [first, ..rest] ->
      LessonInfo(LessonInfoModel(previous: [], current: first, next: rest))
  }
}

fn transition_to_quiz(lesson_info_state: LessonInfoModel) -> LessonPageModel {
  let LessonInfoModel(previous:, current:, next:) = lesson_info_state
  let lessons = list.flatten([previous, [current], next])

  let question_queue =
    list.flat_map(lessons, with: fn(lesson) {
      [Meaning(lesson.id), Reading(lesson.id)]
    })
    |> list.shuffle

  let completion =
    list.map(lessons, with: fn(lesson) {
      LessonCompletion(lesson_id: lesson.id, reading: False, meaning: False)
    })

  LessonQuizModel(question_queue:, completion:, lessons:) |> LessonQuiz
}

fn transition_to_completed(quiz: LessonQuizModel) -> LessonPageModel {
  let LessonQuizModel(question_queue: _, completion:, lessons: _) = quiz
  case list.all(completion, is_lesson_complete) {
    True -> LessonCompleted
    False -> LessonQuiz(quiz)
  }
}

fn handle_correct_answer(
  quiz: LessonQuizModel,
  question: LessonQuestion,
) -> LessonQuizModel {
  let question_queue = remove_question(quiz.question_queue, question)
  let completion = mark_question_complete(quiz.completion, question)

  LessonQuizModel(question_queue:, completion:, lessons: quiz.lessons)
}

fn handle_incorrect_answer(
  quiz: LessonQuizModel,
  question: LessonQuestion,
) -> LessonQuizModel {
  let question_queue = move_question_to_end(quiz.question_queue, question)

  LessonQuizModel(..quiz, question_queue:)
}

fn find_lesson(
  lessons: List(Lesson),
  question: LessonQuestion,
) -> Result(Lesson, Nil) {
  let lesson_id = case question {
    Meaning(id) -> id
    Reading(id) -> id
  }
  list.find(lessons, fn(lesson) { lesson.id == lesson_id })
}

fn find_completion_item(
  completion: List(LessonCompletion),
  question: LessonQuestion,
) -> Result(LessonCompletion, Nil) {
  let lesson_id = case question {
    Meaning(id) -> id
    Reading(id) -> id
  }
  list.find(completion, fn(completion_item) {
    completion_item.lesson_id == lesson_id
  })
}

fn check_answer(
  lesson: Lesson,
  question: LessonQuestion,
  answer: String,
) -> Bool {
  let reference = case question {
    // TODO: Choose a primary definition since some definitons are a semicolon
    // separated list of definitions.
    Meaning(_) -> lesson.definition
    Reading(_) -> lesson.pinyin_input
  }
  answer == reference
}

fn is_lesson_complete(completion: LessonCompletion) -> Bool {
  completion.meaning && completion.reading
}

fn mark_question_complete(
  completion: List(LessonCompletion),
  question: LessonQuestion,
) -> List(LessonCompletion) {
  list.map(completion, fn(completion) {
    case completion, question {
      LessonCompletion(lesson_id:, ..), Meaning(target_id)
        if lesson_id == target_id
      -> LessonCompletion(..completion, meaning: True)
      LessonCompletion(lesson_id:, ..), Reading(target_id)
        if lesson_id == target_id
      -> LessonCompletion(..completion, reading: True)
      _, _ -> completion
    }
  })
}

fn move_question_to_end(
  queue: List(LessonQuestion),
  question: LessonQuestion,
) -> List(LessonQuestion) {
  remove_question(queue, question)
  |> list.append([question])
}

fn remove_question(
  queue: List(LessonQuestion),
  question_to_remove: LessonQuestion,
) -> List(LessonQuestion) {
  list.filter(queue, fn(question) {
    case question, question_to_remove {
      Meaning(id), Meaning(id_to_remove) -> id != id_to_remove
      Reading(id), Reading(id_to_remove) -> id != id_to_remove
      Meaning(_), Reading(_) | Reading(_), Meaning(_) -> True
    }
  })
}

fn next_lesson_info(lesson_info_model: LessonInfoModel) -> LessonInfoModel {
  let LessonInfoModel(previous:, current:, next:) = lesson_info_model
  case next {
    [] -> LessonInfoModel(previous:, current:, next: [])
    [new_current, ..next] ->
      LessonInfoModel(
        previous: [current, ..previous],
        current: new_current,
        next:,
      )
  }
}

fn previous_lesson_info(lesson_info_model: LessonInfoModel) -> LessonInfoModel {
  let LessonInfoModel(previous:, current:, next:) = lesson_info_model
  case previous {
    [] -> LessonInfoModel(previous:, current:, next:)
    [new_current, ..previous] ->
      LessonInfoModel(previous:, current: new_current, next: [current, ..next])
  }
}

// Effects ------------------------------------------------------------------- //
fn fetch_lessons() -> Effect(LessonMsg) {
  let url = api_route.to_string(LessonApiRoute)

  rsvp.get(url, rsvp.expect_ok_response(ClientLoadedLessons))
}

// Views -------------------------------------------------------------------- //
pub fn view(lesson_model: LessonPageModel) -> Element(Msg) {
  case lesson_model {
    LessonLoading -> view_loading()
    LessonInfo(lesson_info_model) -> view_info(lesson_info_model)
    LessonQuiz(lesson_quiz_model) -> view_quiz(lesson_quiz_model)
    LessonCompleted -> todo
  }
}

fn view_loading() -> Element(Msg) {
  html.main([attribute.class("m-5")], [
    view_home_link(),
    html.p([], [html.text("Loading...")]),
  ])
}

fn view_info(lesson_info_model: LessonInfoModel) -> Element(Msg) {
  let Lesson(
    id: _,
    hsk_level:,
    hans:,
    hant:,
    pinyin_input:,
    pinyin_display:,
    definition:,
  ) = lesson_info_model.current
  // TODO: Styling
  // TODO: Disable back button on first item (previous == [])
  html.main([attribute.class("m-5")], [
    view_home_link(),
    html.section([attribute.class("flex items-center")], [
      html.div([attribute.class("shrink-0")], [
        html.button([event.on_click(LessonMsg(UserClickedPreviousInfo))], [
          html.text("<"),
        ]),
      ]),
      html.div([attribute.class("grow text-center")], [
        html.p([], [html.text(hans)]),
        html.p([], [html.text(definition)]),
        html.p([], [html.text(pinyin_display)]),
        html.p([], [html.text(pinyin_input)]),
        html.details([], [
          html.summary([], [html.text("Details")]),
          html.p([], [
            html.text("Traditional Hanzi: " <> hant),
          ]),
          html.p([], [
            html.text(
              "HSK Level: " <> hsk_level.to_int(hsk_level) |> int.to_string,
            ),
          ]),
        ]),
      ]),
      html.button([event.on_click(LessonMsg(UserClickedNextInfo))], [
        html.text(">"),
      ]),
    ]),
  ])
}

fn view_quiz(lesson_quiz_model: LessonQuizModel) -> Element(Msg) {
  html.main([attribute.class("m-5")], [
    view_home_link(),
    html.p([], [html.text("Quiz TODO")]),
  ])
}

fn view_lessons(lessons: List(Lesson)) -> Element(Msg) {
  html.div([], [
    navbar.view(route.Lesson),
    html.main(
      [],
      // TODO: Display quiz page
      list.map(lessons, with: fn(lesson) {
        html.p([], [html.text(lesson.hans)])
      }),
    ),
  ])
}

fn view_no_lessons() {
  html.div([], [
    navbar.view(route.Lesson),

    html.main([], [
      html.h1([attribute.class("text-xl font-semibold text-gray-800")], [
        html.text("Lessons Completed"),
      ]),
    ]),
  ])
}

fn view_home_link() -> Element(Msg) {
  html.a(
    [attribute.href(route.to_path_string(route.Home)), attribute.class("p-2")],
    [html.text("⌂")],
  )
}
