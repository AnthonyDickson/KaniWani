import gleam/http/response.{Response}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp.{HttpError}

import api_route.{Token}
import effects/router
import error_view
import model.{type Model, LoggedOut}
import msg.{
  type LogInMsg, type Msg, LogInMsg, ServerAuthenticatedUser, UserSentLogInForm,
  UserTypedPassword,
}
import password
import route.{Home}

pub fn update(model: Model, msg: LogInMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoggedOut(..), UserTypedPassword(password) -> #(
      LoggedOut(..model, password:),
      effect.none(),
    )

    LoggedOut(..), UserSentLogInForm -> #(
      LoggedOut(..model, log_in_error: None, registration_error: None),
      send_log_in_request(model.password),
    )

    LoggedOut(..), ServerAuthenticatedUser(Ok(_)) -> #(
      model.empty_home_page_model(),
      router.navigate_to(Home),
    )

    LoggedOut(..),
      ServerAuthenticatedUser(Error(HttpError(Response(status: 404, ..))))
    -> #(
      LoggedOut(
        ..model,
        log_in_error: Some("Please set a password before logging in"),
      ),
      effect.none(),
    )

    LoggedOut(..), ServerAuthenticatedUser(Error(_)) -> #(
      LoggedOut(..model, log_in_error: Some("Login failed")),
      effect.none(),
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

fn send_log_in_request(password: String) -> Effect(Msg) {
  let url = api_route.to_string(Token)
  let payload = password.password_to_json(password)

  rsvp.post(
    url,
    payload,
    rsvp.expect_ok_response(fn(result) {
      LogInMsg(ServerAuthenticatedUser(result))
    }),
  )
}

pub fn view(password: String, error: Option(String)) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    LogInMsg(UserSentLogInForm)
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
        event.on_input(fn(input) { LogInMsg(UserTypedPassword(input)) }),
      ]),
      error_view.view_error_paragraph(error),
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
