import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import gzxcvbn.{Feedback}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

import api_route
import effects/router
import error_view
import model.{
  type Model, type RegistrationError, RegisterPage, RegistrationFeedback,
  RegistrationMessage,
}
import msg.{
  type Msg, type RegisterMsg, RegisterMsg, ServerRegisteredUser,
  UserCheckedShowRegisterPassword, UserSentRegistrationForm,
  UserTypedRegisterPassword,
}
import password
import route.{LogIn}

pub fn update(model: Model, msg: RegisterMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    RegisterPage(..), UserCheckedShowRegisterPassword(show_password) -> #(
      RegisterPage(..model, show_password:),
      effect.none(),
    )

    RegisterPage(gzxcvbn_options:, ..), UserTypedRegisterPassword(password) -> {
      case password.check_password_strength(password, gzxcvbn_options) {
        Ok(_) -> #(RegisterPage(..model, password:, error: None), effect.none())
        Error(feedback) -> #(
          RegisterPage(
            ..model,
            password:,
            error: Some(RegistrationFeedback(feedback)),
          ),
          effect.none(),
        )
      }
    }

    RegisterPage(..), UserSentRegistrationForm -> #(
      model,
      send_registration_request(model.password),
    )

    RegisterPage(..), ServerRegisteredUser(Ok(_)) -> #(
      model.empty_login_page_model(),
      router.navigate_to(LogIn),
    )

    RegisterPage(..), ServerRegisteredUser(Error(_)) -> #(
      RegisterPage(
        ..model,
        password: "",
        error: Some(RegistrationMessage("could not register password")),
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

pub fn view(
  password: String,
  show_password: Bool,
  error: Option(RegistrationError),
) -> Element(Msg) {
  let handle_form_submission = fn(_name_value_pairs: List(#(String, String))) -> Msg {
    RegisterMsg(UserSentRegistrationForm)
  }

  let handle_user_input = fn(input) {
    RegisterMsg(UserTypedRegisterPassword(input))
  }

  let handle_show_password_checked = fn(input) {
    RegisterMsg(UserCheckedShowRegisterPassword(input))
  }

  let error_element = case password, error {
    "", _ -> element.none()
    _, Some(RegistrationFeedback(Feedback(warning:, suggestions:))) ->
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
    _, Some(RegistrationMessage(message)) ->
      error_view.view_error_paragraph(Some(message))
    _, None -> element.none()
  }

  let submit_disabled = case password, error {
    "", _ | _, Some(RegistrationFeedback(_)) -> True
    _, _ -> False
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
            html.text("Register"),
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
              // Password field
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
                  attribute.minlength(0),
                  attribute.class(
                    "w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none focus:border-blue-400",
                  ),
                  event.on_input(handle_user_input)
                    |> event.debounce(400),
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

              error_element,

              // Submit button
              html.button(
                [
                  attribute.type_("submit"),
                  attribute.disabled(submit_disabled),
                  attribute.aria_disabled(submit_disabled),
                  attribute.classes([
                    #(
                      "w-full py-2 rounded text-sm text-white transition-colors",
                      True,
                    ),
                    #("bg-blue-500 hover:bg-blue-600", !submit_disabled),
                    #("bg-blue-300 cursor-not-allowed", submit_disabled),
                  ]),
                ],
                [html.text("Register")],
              ),
            ],
          ),
          html.p([], [
            html.text("Already have a password? "),
            html.a(
              [
                attribute.href(route.to_path_string(LogIn)),
                attribute.class("text-blue-500"),
              ],
              [
                html.text("Log in here"),
              ],
            ),
          ]),
        ],
      ),
    ],
  )
}
