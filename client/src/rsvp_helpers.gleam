import gleam/http/response
import gleam/int
import gleam/list
import gleam/pair
import gleam/string

import rsvp

import json_helpers

pub fn describe_error(error: rsvp.Error) -> String {
  let response_to_string = fn(response: response.Response(String)) {
    "status: "
    <> int.to_string(response.status)
    <> "\nheaders: "
    <> response.headers
    |> list.map(fn(key_value) {
      pair.first(key_value) <> ": " <> pair.second(key_value)
    })
    |> string.join("\n")
  }

  case error {
    rsvp.BadBody -> "Bad body"
    rsvp.BadUrl(url) -> "Bad URL: " <> url
    rsvp.HttpError(response) -> "Http Error:\n" <> response_to_string(response)
    rsvp.JsonError(json_error) -> json_helpers.describe_error(json_error)
    rsvp.NetworkError -> "Network error"
    rsvp.UnhandledResponse(response) ->
      "Unhandled response:\n" <> response_to_string(response)
  }
}
