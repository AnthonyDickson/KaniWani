import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri.{type Uri}

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import rsvp

import api_route.{Groceries, Token, TokenStatus}
import groceries.{type GroceryItem, GroceryItem}
import json_helpers
import password
import route.{type Route, Foo, Home, LogIn, LogOut, Register}
import rsvp_helpers

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
      check_auth_status(),
    ]),
  )
}

fn on_url_change(uri: Uri) -> Msg {
  ClientChangedRoute(route.from_uri(uri))
}

// Model ----------------------------------------------------------------------

type Model {
  Authenticated(
    route: Route,
    items: List(GroceryItem),
    new_item: String,
    saving: Bool,
    error: Option(String),
  )
  LoadingPage(show: Route, next: Route)
  CheckingAuth(Route)
  LoggedOut(
    route: Route,
    /// The password entered in the log in or registration form
    password: String,
    log_in_error: Option(String),
    registration_error: Option(String),
  )
}

fn empty_logged_out(route: Route) -> Model {
  LoggedOut(route, password: "", log_in_error: None, registration_error: None)
}

// Update ---------------------------------------------------------------------

type Msg {
  // Auth flow
  UserTypedPassword(String)
  UserSentRegistrationForm
  ServerRegisteredUser(Result(Response(String), rsvp.Error))
  UserSentLogInForm
  ServerAuthenticatedUser(Result(Response(String), rsvp.Error))
  ServerLoggedOutUser(Result(Response(String), rsvp.Error))
  // Routing
  ClientChangedRoute(new_route: Route)
  // Groceries Page
  ServerSavedList(Result(Response(String), rsvp.Error))
  ServerLoadedList(Result(Response(String), rsvp.Error))
  UserAddedItem
  UserTypedNewItem(String)
  UserSavedList
  UserUpdatedQuantity(index: Int, quantity: Int)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model {
    Authenticated(route:, ..) ->
      case msg {
        ServerSavedList(Ok(_)) -> #(
          Authenticated(..model, saving: False, error: None),
          effect.none(),
        )

        ServerSavedList(Error(error)) -> {
          use <- auto_logout(error)
          #(
            Authenticated(
              ..model,
              saving: False,
              error: Some("Failed to save list"),
            ),
            effect.none(),
          )
        }

        ClientChangedRoute(LogOut) -> #(model, send_log_out_request())

        ClientChangedRoute(LogIn) | ClientChangedRoute(Register) -> #(
          model,
          modem.push(route.to_path_string(route), None, None),
        )

        ClientChangedRoute(route) -> #(
          Authenticated(..model, route:),
          set_title(route.to_page_title(route)),
        )

        ServerLoggedOutUser(..) -> #(
          empty_logged_out(LogIn),
          modem.push(route.to_path_string(LogIn), None, None),
        )

        UserAddedItem -> {
          case model.new_item {
            "" -> #(model, effect.none())
            name -> {
              let item = GroceryItem(name:, quantity: 1)
              let updated_items = list.append(model.items, [item])

              #(
                Authenticated(..model, items: updated_items, new_item: ""),
                effect.none(),
              )
            }
          }
        }

        UserTypedNewItem(text) -> #(
          Authenticated(..model, new_item: text),
          effect.none(),
        )

        UserSavedList -> #(
          Authenticated(..model, saving: True),
          save_list(model.items),
        )

        UserUpdatedQuantity(index:, quantity:) -> {
          let updated_items =
            list.index_map(model.items, fn(item, item_index) {
              case item_index == index {
                True -> GroceryItem(..item, quantity:)
                False -> item
              }
            })

          #(Authenticated(..model, items: updated_items), effect.none())
        }

        _ -> #(model, effect.none())
      }
    LoadingPage(_, target_route) ->
      case msg {
        ServerLoadedList(Ok(response)) -> {
          let items =
            json.parse(response.body, groceries.grocery_list_decoder())
          let #(items, error) = case items {
            Ok(items) -> #(items, None)
            Error(error) -> #([], Some(json_helpers.describe_error(error)))
          }
          #(
            Authenticated(
              target_route,
              items:,
              new_item: "",
              saving: False,
              error:,
            ),
            modem.push(route.to_path_string(Home), None, None),
          )
        }

        ServerLoadedList(Error(error)) -> #(
          Authenticated(
            target_route,
            items: [],
            new_item: "",
            saving: False,
            error: Some(rsvp_helpers.describe_error(error)),
          ),
          modem.push(route.to_path_string(Home), None, None),
        )

        _ -> #(model, effect.none())
      }
    CheckingAuth(route) ->
      case msg {
        ServerAuthenticatedUser(Ok(_)) -> #(
          LoadingPage(route, Home),
          get_list(),
        )

        ServerAuthenticatedUser(Error(_)) -> #(
          empty_logged_out(LogIn),
          modem.push(route.to_path_string(LogIn), None, None),
        )

        _ -> #(model, effect.none())
      }
    LoggedOut(..) ->
      case msg {
        ClientChangedRoute(Register as route)
        | ClientChangedRoute(LogIn as route) -> #(
          empty_logged_out(route),
          set_title(route.to_page_title(route)),
        )

        ClientChangedRoute(_) -> #(
          model,
          modem.replace(route.to_path_string(model.route), None, None),
        )

        UserTypedPassword(password) -> #(
          LoggedOut(..model, password:),
          effect.none(),
        )

        UserSentLogInForm -> #(
          LoggedOut(..model, log_in_error: None, registration_error: None),
          send_log_in_request(model.password),
        )

        UserSentRegistrationForm -> #(
          model,
          send_registration_request(model.password),
        )

        ServerRegisteredUser(Ok(_)) -> #(
          empty_logged_out(LogIn),
          modem.push(route.to_path_string(LogIn), None, None),
        )

        ServerRegisteredUser(Error(_)) -> #(
          LoggedOut(
            ..model,
            registration_error: Some("could not register password"),
          ),
          effect.none(),
        )

        ServerAuthenticatedUser(Ok(_)) -> #(
          LoadingPage(model.route, Home),
          get_list(),
        )

        ServerAuthenticatedUser(Error(_)) -> #(
          LoggedOut(..model, log_in_error: Some("Login failed")),
          effect.none(),
        )

        _ -> #(model, effect.none())
      }
  }
}

fn auto_logout(
  error: rsvp.Error,
  callback: fn() -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case error {
    rsvp.HttpError(resp) if resp.status == 401 -> #(
      LoggedOut(
        LogIn,
        password: "",
        log_in_error: Some("Token expired or is invalid. Please sign in again"),
        registration_error: None,
      ),
      modem.push(route.to_path_string(LogIn), None, None),
    )
    _ -> callback()
  }
}

fn check_auth_status() -> Effect(Msg) {
  let url = api_route.to_string(TokenStatus)

  rsvp.get(url, rsvp.expect_ok_response(ServerAuthenticatedUser))
}

fn send_registration_request(password: String) -> Effect(Msg) {
  let url = api_route.to_string(api_route.Register)
  let payload = password.password_to_json(password)

  rsvp.post(url, payload, rsvp.expect_ok_response(ServerRegisteredUser))
}

fn send_log_in_request(password: String) -> Effect(Msg) {
  let url = api_route.to_string(Token)
  let payload = password.password_to_json(password)

  rsvp.post(url, payload, rsvp.expect_ok_response(ServerAuthenticatedUser))
}

fn send_log_out_request() -> Effect(Msg) {
  let scheme = case get_scheme_js() {
    "http" -> http.Http
    _ -> http.Https
  }

  request.new()
  |> request.set_scheme(scheme)
  |> request.set_host(get_host_js())
  |> request.set_method(http.Delete)
  |> request.set_path(api_route.to_string(Token))
  |> rsvp.send(rsvp.expect_any_response(ServerLoggedOutUser))
}

@external(javascript, "./client.ffi.mjs", "getScheme")
fn get_scheme_js() -> String

@external(javascript, "./client.ffi.mjs", "getHost")
fn get_host_js() -> String

fn get_list() -> Effect(Msg) {
  let url = api_route.to_string(Groceries)

  rsvp.get(url, rsvp.expect_ok_response(ServerLoadedList))
}

fn save_list(items: List(GroceryItem)) -> Effect(Msg) {
  let body = groceries.grocery_list_to_json(items)
  let url = api_route.to_string(Groceries)

  rsvp.post(url, body, rsvp.expect_ok_response(ServerSavedList))
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
            Home -> view_home(items:, new_item:, saving:, error:)
            Foo -> view_foo()
            _ -> view_not_found()
          }
        }
        LoadingPage(..) -> view_loading()
        CheckingAuth(..) -> view_loading()
        LoggedOut(password:, route: Register, registration_error:, ..) ->
          view_registration(password, registration_error)
        LoggedOut(password:, route: LogIn, log_in_error:, ..) ->
          view_log_in(password, log_in_error)
        LoggedOut(..) -> view_not_found()
      },
    ]),
  ])
}

fn view_home(
  items items: List(GroceryItem),
  new_item new_item: String,
  saving saving: Bool,
  error error: Option(String),
) -> Element(Msg) {
  let styles = [
    #("max-width", "30ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  html.div([attribute.styles(styles)], [
    html.h1(
      [attribute.class("text-3xl font-bold underline text-center mt-10")],
      [html.text("Grocery List")],
    ),
    view_grocery_list(items),
    view_new_item(new_item),
    html.div([], [
      html.button([event.on_click(UserSavedList), attribute.disabled(saving)], [
        html.text(case saving {
          True -> "Saving..."
          False -> "Save List"
        }),
      ]),
    ]),
    view_error_paragraph(error),
  ])
}

fn view_log_in(password: String, error: Option(String)) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    UserSentLogInForm
  }

  html.div([], [
    html.h1([attribute.class("text-xl")], [html.text("Log In")]),
    html.form([event.on_submit(handle_form_submission)], [
      html.label([attribute.for("password")], [html.text("Password")]),
      html.input([
        attribute.id("password"),
        attribute.type_("password"),
        attribute.value(password),
        attribute.placeholder("********"),
        event.on_input(UserTypedPassword),
      ]),
      view_error_paragraph(error),
      html.button(
        [
          attribute.class("rounded text-white bg-blue-500 px-2 py-2"),
          attribute.role("submit"),
        ],
        [
          html.text("Log In"),
        ],
      ),
    ]),
  ])
}

fn view_registration(password: String, error: Option(String)) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    UserSentRegistrationForm
  }

  html.div([], [
    html.h1([attribute.class("text-xl")], [html.text("Register")]),
    html.form([event.on_submit(handle_form_submission)], [
      html.label([attribute.for("password")], [html.text("Password")]),
      html.input([
        attribute.id("password"),
        attribute.type_("password"),
        attribute.value(password),
        attribute.placeholder("********"),
        event.on_input(UserTypedPassword),
      ]),
      view_error_paragraph(error),
      html.button(
        [
          attribute.class("rounded text-white bg-blue-500 px-2 py-2"),
          attribute.role("submit"),
        ],
        [html.text("Register")],
      ),
    ]),
  ])
}

fn view_error_paragraph(error: Option(String)) -> Element(Msg) {
  case error {
    Some(text) -> html.p([attribute.class("text-red-500")], [html.text(text)])
    None -> element.none()
  }
}

fn view_new_item(new_item: String) -> Element(Msg) {
  html.div([], [
    html.input([
      attribute.placeholder("Enter item name"),
      attribute.value(new_item),
      event.on_input(UserTypedNewItem),
    ]),
    html.button([event.on_click(UserAddedItem)], [html.text("Add")]),
  ])
}

fn view_grocery_list(items: List(GroceryItem)) -> Element(Msg) {
  case items {
    [] -> html.p([], [html.text("No items in your list yet.")])
    _ -> {
      html.ul(
        [],
        list.index_map(items, fn(item, index) {
          html.li([], [view_grocery_item(item, index)])
        }),
      )
    }
  }
}

fn view_grocery_item(item: GroceryItem, index: Int) -> Element(Msg) {
  html.div([attribute.styles([#("display", "flex"), #("gap", "1em")])], [
    html.span([attribute.style("flex", "1")], [html.text(item.name)]),
    html.input([
      attribute.style("width", "4em"),
      attribute.type_("number"),
      attribute.value(int.to_string(item.quantity)),
      attribute.min("0"),
      event.on_input(fn(value) {
        int.parse(value)
        |> result.unwrap(0)
        |> UserUpdatedQuantity(index, quantity: _)
      }),
    ]),
  ])
}

fn view_foo() -> Element(Msg) {
  let styles = [
    #("max-width", "30ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  html.div([attribute.styles(styles)], [
    html.h1([], [html.text("Foo")]),
  ])
}

fn view_not_found() -> Element(Msg) {
  html.div([], [html.h1([], [html.text("Page Not Found")])])
}

fn view_loading() -> Element(Msg) {
  html.div([], [html.h1([], [html.text("Loading...")])])
}
