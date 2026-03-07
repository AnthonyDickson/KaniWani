import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import msg.{type Msg}

pub fn view_error_paragraph(error: Option(String)) -> Element(Msg) {
  case error {
    Some(text) -> html.p([attribute.class("text-red-500")], [html.text(text)])
    None -> element.none()
  }
}
