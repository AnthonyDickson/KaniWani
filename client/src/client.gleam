import gleam/io
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem

import effects/router
import effects/session
import model.{
  type Model, CheckingAuth, FooPage, HomePage, LogInPage, NotFoundPage,
  RegisterPage,
}
import msg.{
  type Msg, ClientChangedRoute, HomeMsg, LogInMsg, RegisterMsg,
  ServerAuthenticatedUser, ServerLoggedOutUser, UserNavigatedToHomePage,
}
import page/foo
import page/home
import page/log_in
import page/register
import route.{type Route, Foo, Home, LogIn, LogOut, NotFound, Register}

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

  let model = CheckingAuth

  #(
    model,
    effect.batch([
      modem.init(on_url_change),
      set_title(route.to_page_title(route)),
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
    CheckingAuth, LogInMsg(ServerAuthenticatedUser(Ok(_))) -> #(
      model.empty_home_page_model(),
      router.navigate_to(Home),
    )

    CheckingAuth, LogInMsg(ServerAuthenticatedUser(Error(_))) -> #(
      model.empty_login_page_model(),
      router.navigate_to(LogIn),
    )

    LogInPage(..), ClientChangedRoute(route) ->
      handle_login_page_route_change(model, route)
    LogInPage(..), LogInMsg(msg) -> log_in.update(model, msg)

    RegisterPage(..), ClientChangedRoute(route) ->
      handle_register_page_route_change(model, route)
    RegisterPage(..), RegisterMsg(msg) -> register.update(model, msg)

    _, ClientChangedRoute(LogOut) -> #(model, session.send_log_out_request())
    _, ServerLoggedOutUser(..) -> #(
      model.empty_login_page_model(),
      router.navigate_to(LogIn),
    )

    _, ClientChangedRoute(LogIn) | _, ClientChangedRoute(Register) -> #(
      model,
      modem.back(1),
    )

    _, ClientChangedRoute(Home as route) -> #(
      model.empty_home_page_model(),
      effect.batch([
        effect.from(fn(dispatch) { dispatch(HomeMsg(UserNavigatedToHomePage)) }),
        set_title(route.to_page_title(route)),
      ]),
    )
    HomePage(..), HomeMsg(msg) -> home.update(model, msg)

    _, ClientChangedRoute(Foo as route) -> #(
      FooPage,
      set_title(route.to_page_title(route)),
    )

    _, ClientChangedRoute(NotFound as route) -> #(
      NotFoundPage,
      set_title(route.to_page_title(route)),
    )

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
    Register -> #(
      model.empty_register_page_model(),
      router.navigate_to(Register),
    )
    LogIn -> #(model, set_title(route.to_page_title(LogIn)))
    _ -> #(model.empty_login_page_model(), router.navigate_to(LogIn))
  }
}

fn handle_register_page_route_change(
  model: Model,
  target_route: Route,
) -> #(Model, Effect(Msg)) {
  case target_route {
    LogIn -> #(model.empty_login_page_model(), router.navigate_to(LogIn))
    Register -> #(model, set_title(route.to_page_title(Register)))
    _ -> #(model.empty_register_page_model(), router.navigate_to(Register))
  }
}

fn set_title(title: String) -> Effect(Msg) {
  use _ <- effect.from
  set_title_js(title)
}

@external(javascript, "./client.ffi.mjs", "setTitle")
fn set_title_js(title: String) -> Nil

// View -----------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model {
    HomePage(items:, new_item:, loading:, saving:, error:) ->
      home.view(items:, new_item:, loading:, saving:, error:)
    FooPage -> foo.view()
    CheckingAuth -> view_loading()
    RegisterPage(password:, show_password:, error:, ..) ->
      register.view(password, show_password, error)
    LogInPage(password:, show_password:, error:) ->
      log_in.view(password, show_password, error)
    _ -> view_not_found()
  }
}

fn view_not_found() -> Element(Msg) {
  html.div([], [
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
  html.div([], [html.h1([], [html.text("Loading...")])])
}
