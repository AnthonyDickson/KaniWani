import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import rsvp

import api_route
import error_view
import model.{type Model, LoggedOut}
import msg.{
  type Msg, type RegisterMsg, RegisterMsg, ServerRegisteredUser,
  UserSentRegistrationForm, UserTypedRegisterPassword,
}
import password
import route.{LogIn}

pub fn update(model: Model, msg: RegisterMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoggedOut(..), UserTypedRegisterPassword(password) -> #(
      LoggedOut(..model, password:),
      effect.none(),
    )

    LoggedOut(..), UserSentRegistrationForm -> #(
      model,
      send_registration_request(model.password),
    )

    LoggedOut(..), ServerRegisteredUser(Ok(_)) -> #(
      model.empty_logged_out(LogIn),
      modem.push(route.to_path_string(LogIn), None, None),
    )

    LoggedOut(..), ServerRegisteredUser(Error(_)) -> #(
      LoggedOut(
        ..model,
        registration_error: Some("could not register password"),
      ),
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

fn send_registration_request(password: String) -> Effect(Msg) {
  let url = api_route.to_string(api_route.Register)
  let payload = password.password_to_json(password)

  rsvp.post(
    url,
    payload,
    rsvp.expect_ok_response(fn(result) {
      RegisterMsg(ServerRegisteredUser(result))
    }),
  )
}

pub fn view(password: String, error: Option(String)) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    RegisterMsg(UserSentRegistrationForm)
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
        event.on_input(fn(input) {
          RegisterMsg(UserTypedRegisterPassword(input))
        }),
      ]),
      error_view.view_error_paragraph(error),
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
