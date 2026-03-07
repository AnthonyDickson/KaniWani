import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem

import auth
import model.{type Model, Authenticated, CheckingAuth, LoadingPage, LoggedOut}
import msg.{
  type Msg, ClientChangedRoute, HomeMsg, LogInMsg, RegisterMsg,
  ServerAuthenticatedUser, ServerLoggedOutUser,
}
import page/foo
import page/home
import page/login
import page/register
import route.{type Route, Foo, Home, LogIn, LogOut, Register}

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
    CheckingAuth(route), LogInMsg(ServerAuthenticatedUser(Ok(_))) -> #(
      LoadingPage(route, Home),
      home.get_list() |> effect.map(HomeMsg),
    )

    CheckingAuth(..), LogInMsg(ServerAuthenticatedUser(Error(_))) -> #(
      model.empty_logged_out(LogIn),
      modem.push(route.to_path_string(LogIn), None, None),
    )

    LoggedOut(..), ClientChangedRoute(Register as route)
    | LoggedOut(..), ClientChangedRoute(LogIn as route)
    -> #(model.empty_logged_out(route), set_title(route.to_page_title(route)))

    LoggedOut(..), ClientChangedRoute(_) -> #(
      model,
      modem.push(route.to_path_string(model.route), None, None),
    )

    LoggedOut(..), LogInMsg(msg) -> login.update(model, msg)
    LoggedOut(..), RegisterMsg(msg) -> register.update(model, msg)

    Authenticated(..), ClientChangedRoute(LogOut) -> #(
      model,
      auth.send_log_out_request(),
    )

    Authenticated(..), ClientChangedRoute(LogIn)
    | Authenticated(..), ClientChangedRoute(Register)
    -> #(model, modem.push(route.to_path_string(model.route), None, None))

    Authenticated(..), ClientChangedRoute(route) -> #(
      Authenticated(..model, route:),
      set_title(route.to_page_title(route)),
    )

    Authenticated(..), ServerLoggedOutUser(..) -> #(
      model.empty_logged_out(LogIn),
      modem.push(route.to_path_string(LogIn), None, None),
    )

    Authenticated(..), HomeMsg(msg) | LoadingPage(..), HomeMsg(msg) ->
      home.update(model, msg)

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
    Authenticated(..) -> [Home, Foo, LogOut]
    _ -> [LogIn, Register]
  }
  let is_current_page = fn(route: Route) -> Bool {
    case model {
      Authenticated(route: current_route, ..)
      | LoggedOut(route: current_route, ..) -> route == current_route
      LoadingPage(..) | CheckingAuth(..) -> False
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
    html.main([attribute.class("p-5")], [
      case model {
        Authenticated(route:, items:, new_item:, saving:, error:) -> {
          case route {
            Home -> home.view(items:, new_item:, saving:, error:)
            Foo -> foo.view()
            _ -> view_not_found()
          }
        }
        LoadingPage(..) -> view_loading()
        CheckingAuth(..) -> view_loading()
        LoggedOut(password:, route: Register, registration_error:, ..) ->
          register.view(password, registration_error)
        LoggedOut(password:, route: LogIn, log_in_error:, ..) ->
          login.view(password, log_in_error)
        LoggedOut(..) -> view_not_found()
      },
    ]),
  ])
}

fn view_not_found() -> Element(Msg) {
  html.div([], [html.h1([], [html.text("Page Not Found")])])
}

fn view_loading() -> Element(Msg) {
  html.div([], [html.h1([], [html.text("Loading...")])])
}
