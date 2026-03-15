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
  type LogInMsg, type Msg, LogInMsg, ServerAuthenticatedUser,
  UserCheckedShowPassword, UserSentLogInForm, UserTypedPassword,
}
import password
import route.{Home}

pub fn update(model: Model, msg: LogInMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoggedOut(..), UserCheckedShowPassword(show_password) -> #(
      LoggedOut(..model, show_password:),
      effect.none(),
    )

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

pub fn view(
  password: String,
  show_password: Bool,
  error: Option(String),
) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    LogInMsg(UserSentLogInForm)
  }

  let handle_show_password_checked = fn(input) {
    LogInMsg(UserCheckedShowPassword(input))
  }

  let password_input_type = case show_password {
    True -> "text"
    False -> "password"
  }

  html.main(
    [
      attribute.class(
        "min-h-screen bg-gray-50 flex items-center justify-center",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "w-80 bg-white border border-gray-200 rounded-lg p-8 space-y-6",
          ),
        ],
        [
          html.h1([attribute.class("text-xl font-semibold text-gray-800")], [
            html.text("Log In"),
          ]),
          html.form(
            [
              // https://technology.blog.gov.uk/2021/04/19/simple-things-are-complicated-making-a-show-password-option/
              // https://stackoverflow.com/a/14788666
              attribute.autocomplete("off"),
              attribute.class("space-y-4"),
              event.on_submit(handle_form_submission),
            ],
            [
              html.div([attribute.class("space-y-1")], [
                html.label(
                  [
                    attribute.for("password"),
                    attribute.class("text-sm text-gray-600"),
                  ],
                  [html.text("Password")],
                ),
                html.input([
                  attribute.id("password"),
                  attribute.type_(password_input_type),
                  attribute.value(password),
                  attribute.placeholder("••••••••"),
                  attribute.required(True),
                  attribute.minlength(1),
                  attribute.class(
                    "w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none focus:border-blue-400",
                  ),
                  event.on_input(fn(input) {
                    LogInMsg(UserTypedPassword(input))
                  }),
                ]),
              ]),
              // Show password toggle
              html.div(
                [attribute.class("flex items-center gap-2 cursor-pointer")],
                [
                  html.input([
                    attribute.id("show-password"),
                    attribute.type_("checkbox"),
                    attribute.checked(show_password),
                    event.on_check(handle_show_password_checked),
                  ]),
                  html.label(
                    [
                      attribute.for("show-password"),
                      attribute.class("text-sm text-gray-600"),
                    ],
                    [
                      html.text("Show password"),
                    ],
                  ),
                ],
              ),

              // Submit button
              error_view.view_error_paragraph(error),
              html.button(
                [
                  attribute.type_("submit"),
                  attribute.class(
                    "w-full py-2 rounded text-sm text-white bg-blue-500 hover:bg-blue-600 transition-colors",
                  ),
                ],
                [html.text("Log In")],
              ),
            ],
          ),
          html.p([], [
            html.text("Don't have a password yet? "),
            html.a(
              [
                attribute.href(route.to_path_string(route.Register)),
                attribute.class("text-blue-500"),
              ],
              [
                html.text("Register here"),
              ],
            ),
          ]),
        ],
      ),
    ],
  )
}
