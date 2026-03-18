import gleam/http
import gleam/http/request
import gleam/option.{None}

import lustre/effect.{type Effect}
import modem
import rsvp.{type Error}

import api_route.{Token, TokenStatus}
import model.{type Model}
import msg.{type Msg, LogInMsg, ServerAuthenticatedUser, ServerLoggedOutUser}
import route.{LogIn}

pub fn auto_logout(
  error: Error,
  callback: fn() -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case error {
    rsvp.HttpError(resp) if resp.status == 401 -> #(
      model.empty_login_page_model(),
      modem.push(route.to_path_string(LogIn), None, None),
    )
    _ -> callback()
  }
}

pub fn check_auth_status() -> Effect(Msg) {
  let url = api_route.to_string(TokenStatus)

  rsvp.get(
    url,
    rsvp.expect_ok_response(fn(result) {
      LogInMsg(ServerAuthenticatedUser(result))
    }),
  )
}

pub fn send_log_out_request() -> Effect(Msg) {
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

@external(javascript, "./auth.ffi.mjs", "getScheme")
fn get_scheme_js() -> String

@external(javascript, "./auth.ffi.mjs", "getHost")
fn get_host_js() -> String
