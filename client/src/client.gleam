import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem

import effects/auth
import effects/router
import model.{
  type Model, CheckingAuth, FooPage, HomePage, LoggedOut, NotFoundPage,
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
      auth.check_auth_status(),
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
      model.empty_logged_out_model(LogIn),
      router.navigate_to(LogIn),
    )

    LoggedOut(..), ClientChangedRoute(Register as route)
    | LoggedOut(..), ClientChangedRoute(LogIn as route)
    -> #(
      model.empty_logged_out_model(route),
      set_title(route.to_page_title(route)),
    )

    LoggedOut(..), ClientChangedRoute(_) -> #(
      model,
      router.navigate_to(model.route),
    )

    LoggedOut(..), LogInMsg(msg) -> log_in.update(model, msg)
    LoggedOut(..), RegisterMsg(msg) -> register.update(model, msg)

    _, ClientChangedRoute(LogOut) -> #(model, auth.send_log_out_request())

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

    _, ClientChangedRoute(Foo as route) -> #(
      FooPage,
      set_title(route.to_page_title(route)),
    )

    _, ClientChangedRoute(NotFound as route) -> #(
      NotFoundPage,
      set_title(route.to_page_title(route)),
    )

    _, ServerLoggedOutUser(..) -> #(
      model.empty_logged_out_model(LogIn),
      router.navigate_to(LogIn),
    )

    HomePage(..), HomeMsg(msg) -> home.update(model, msg)

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

fn set_title(title: String) -> Effect(Msg) {
  use _ <- effect.from
  set_title_js(title)
}

@external(javascript, "./client.ffi.mjs", "setTitle")
fn set_title_js(title: String) -> Nil

// View -----------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let nav_items = case model {
    LoggedOut(..) -> [LogIn, Register]
    _ -> [Home, Foo, LogOut]
  }

  let is_current_page = fn(route: Route) -> Bool {
    case model {
      HomePage(..) -> route == Home
      FooPage -> route == Foo
      LoggedOut(route: current_route, ..) -> route == current_route
      CheckingAuth | NotFoundPage -> False
    }
  }

  html.div([], [
    html.nav(
      [attribute.class("p-2 bg-white shadow-md")],
      list.map(nav_items, fn(route) {
        html.a(
          [
            attribute.href(route.to_path_string(route)),
            attribute.class("mx-1 p-1"),
            attribute.classes([
              #("border-b-2 border-blue-500", is_current_page(route)),
            ]),
          ],
          [html.text(route.to_page_name(route))],
        )
      }),
    ),
    html.main([], [
      case model {
        HomePage(items:, new_item:, loading:, saving:, error:) ->
          home.view(items:, new_item:, loading:, saving:, error:)
        FooPage -> foo.view()
        CheckingAuth -> view_loading()
        LoggedOut(
          password:,
          route: Register,
          registration_error:,
          show_password:,
          ..,
        ) -> register.view(password, show_password, registration_error)
        LoggedOut(password:, route: LogIn, log_in_error:, show_password:, ..) ->
          log_in.view(password, show_password, log_in_error)
        _ -> view_not_found()
      },
    ]),
  ])
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
