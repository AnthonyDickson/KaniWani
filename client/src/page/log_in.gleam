import gleam/io
import gleam/option.{None}
import gleam/string
import gleam/uri
import lustre/event
import modem

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

import api_route.{OAuthLogin}
import model.{type Model, LogInPage}
import msg.{type LogInMsg, type Msg, LogInMsg, UserClickedLogin}

pub fn update(model: Model, msg: LogInMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LogInPage, UserClickedLogin -> #(
      model,
      modem.load(uri.Uri(
        scheme: None,
        userinfo: None,
        host: None,
        port: None,
        path: api_route.to_string(OAuthLogin),
        query: None,
        fragment: None,
      )),
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

pub fn view() -> Element(Msg) {
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
            html.text("KaniWani"),
          ]),
          html.a(
            [
              event.on_click(LogInMsg(UserClickedLogin)),
              attribute.class(
                "block w-full py-2 rounded text-sm text-white text-center bg-blue-500 hover:bg-blue-600 transition-colors",
              ),
            ],
            [html.text("Log in with KaniDM")],
          ),
        ],
      ),
    ],
  )
}
