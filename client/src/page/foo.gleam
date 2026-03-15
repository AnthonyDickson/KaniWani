import lustre/attribute
import lustre/element
import lustre/element/html

import msg
import navbar
import route.{Foo}

pub fn view() -> element.Element(msg.Msg) {
  let styles = [
    #("max-width", "30ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  html.div([], [
    navbar.view(Foo),
    html.main([attribute.styles(styles)], [
      html.h1([], [html.text("Foo")]),
    ]),
  ])
}
