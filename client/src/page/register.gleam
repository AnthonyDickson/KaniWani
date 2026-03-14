import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gzxcvbn

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

import api_route
import effects/router
import error_view
import model.{type Model, type RegistrationError, Feedback, LoggedOut, String}
import msg.{
  type Msg, type RegisterMsg, RegisterMsg, ServerRegisteredUser,
  UserSentRegistrationForm, UserTypedRegisterPassword,
}
import password
import route.{LogIn}

pub fn update(model: Model, msg: RegisterMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoggedOut(gzxcvbn_options:, ..), UserTypedRegisterPassword(password) -> {
      case password.check_password_strength(password, gzxcvbn_options) {
        Ok(_) -> #(
          LoggedOut(..model, password:, registration_error: None),
          effect.none(),
        )
        Error(feedback) -> #(
          LoggedOut(
            ..model,
            password:,
            registration_error: Some(Feedback(feedback)),
          ),
          effect.none(),
        )
      }
    }

    LoggedOut(..), UserSentRegistrationForm -> #(
      model,
      send_registration_request(model.password),
    )

    LoggedOut(..), ServerRegisteredUser(Ok(_)) -> #(
      model.empty_logged_out_model(LogIn),
      router.navigate_to(LogIn),
    )

    LoggedOut(..), ServerRegisteredUser(Error(_)) -> #(
      LoggedOut(
        ..model,
        password: "",
        registration_error: Some(String("could not register password")),
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

pub fn view(password: String, error: Option(RegistrationError)) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    RegisterMsg(UserSentRegistrationForm)
  }

  let handle_user_input = fn(input) {
    RegisterMsg(UserTypedRegisterPassword(input))
  }

  let error_element = case password, error {
    "", _ -> element.none()
    _, Some(Feedback(gzxcvbn.Feedback(warning:, suggestions:))) ->
      html.div([], [
        html.p([attribute.class("text-red-500")], [
          html.text(warning),
        ]),
        html.ul(
          [],
          list.map(suggestions, fn(suggestion) {
            html.li([], [html.text("Hint: " <> suggestion)])
          }),
        ),
      ])
    _, Some(String(message)) -> error_view.view_error_paragraph(Some(message))
    _, None -> element.none()
  }

  let submit_disabled = case password, error {
    "", _ | _, Some(Feedback(_)) -> True
    _, _ -> False
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
        attribute.required(True),
        attribute.minlength(0),
        event.on_input(handle_user_input)
          |> event.debounce(400),
      ]),
      html.button(
        [
          attribute.class("rounded text-white  px-2 py-2"),
          attribute.classes([
            #("bg-blue-500", !submit_disabled),
            #("bg-blue-300", submit_disabled),
          ]),
          attribute.role("submit"),
          attribute.disabled(submit_disabled),
          attribute.aria_disabled(submit_disabled),
        ],
        [html.text("Register")],
      ),
      error_element,
    ]),
  ])
}
