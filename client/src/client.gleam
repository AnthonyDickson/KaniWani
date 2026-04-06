import gleam/io
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import kaniwani/client/effects/router
import kaniwani/client/effects/session
import kaniwani/client/model.{
  type Model, CheckingAuth, HomePage, LessonPage, LogInPage, NotFoundPage,
}
import kaniwani/client/msg.{
  type Msg, ClientChangedRoute, HomeMsg, LessonMsg, LogInMsg,
  ServerAuthenticatedUser, ServerLoggedOutUser, UserNavigatedToHomePage,
  UserNavigatedToLessonPage,
}
import kaniwani/client/page/home
import kaniwani/client/page/lesson
import kaniwani/client/page/log_in
import kaniwani/client/route.{type Route, Home, Lesson, LogIn, LogOut, NotFound}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  let route =
    modem.initial_uri()
    |> result.unwrap(uri.empty)
    |> route.from_uri

  let model = CheckingAuth(route)

  #(
    model,
    effect.batch([
      modem.init(on_url_change),
      router.update_title(route),
      session.check_session_status(),
    ]),
  )
}

fn on_url_change(uri: Uri) -> Msg {
  ClientChangedRoute(route.from_uri(uri))
}

// Update ---------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model, msg {
    CheckingAuth(redirect_to: target_route),
      LogInMsg(ServerAuthenticatedUser(Ok(_)))
    -> #(model.empty_home_page_model(), router.replace(target_route))

    CheckingAuth(_), LogInMsg(ServerAuthenticatedUser(Error(_))) -> #(
      model.empty_login_page_model(),
      router.navigate(to: LogIn),
    )

    LogInPage(..), ClientChangedRoute(route) ->
      handle_login_page_route_change(model, route)
    LogInPage(..), LogInMsg(msg) -> log_in.update(model, msg)

    _, ClientChangedRoute(LogOut) -> #(model, session.send_log_out_request())
    _, ServerLoggedOutUser(..) -> #(
      model.empty_login_page_model(),
      router.navigate(to: LogIn),
    )

    _, ClientChangedRoute(LogIn) -> #(model, modem.back(1))

    _, ClientChangedRoute(Home) -> #(
      model.empty_home_page_model(),
      effect.batch([
        effect.from(fn(dispatch) { dispatch(HomeMsg(UserNavigatedToHomePage)) }),
        router.update_title(Home),
      ]),
    )
    HomePage(..), HomeMsg(msg) -> home.update(model, msg)

    _, ClientChangedRoute(Lesson) -> #(
      LessonPage([]),
      effect.batch([
        effect.from(fn(dispatch) {
          dispatch(LessonMsg(UserNavigatedToLessonPage))
        }),
        router.update_title(Lesson),
      ]),
    )
    LessonPage(..), LessonMsg(msg) -> lesson.update(model, msg)

    _, ClientChangedRoute(NotFound) -> #(NotFoundPage, effect.none())

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

fn handle_login_page_route_change(
  model: Model,
  target_route: Route,
) -> #(Model, Effect(Msg)) {
  case target_route {
    LogIn -> #(model, router.update_title(LogIn))
    _ -> #(model.empty_login_page_model(), router.navigate(LogIn))
  }
}

// View -----------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model {
    HomePage(items:, new_item:, loading:, saving:, error:) ->
      home.view(items:, new_item:, loading:, saving:, error:)
    CheckingAuth(_) -> view_loading()
    LogInPage(password:, show_password:, error:) ->
      log_in.view(password, show_password, error)
    LessonPage(lessons) -> lesson.view(lessons)
    NotFoundPage -> view_not_found()
  }
}

fn view_not_found() -> Element(Msg) {
  html.main([], [
    html.h1([attribute.class("text-lg font-bold")], [
      html.text("Page Not Found"),
    ]),
    html.a(
      [
        attribute.href(route.to_path_string(Home)),
        attribute.class("text-blue-600 underline"),
      ],
      [
        html.text("Take me home"),
      ],
    ),
  ])
}

fn view_loading() -> Element(Msg) {
  html.main([], [html.h1([], [html.text("Loading...")])])
}
