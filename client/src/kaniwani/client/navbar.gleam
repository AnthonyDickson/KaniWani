import gleam/list
import kaniwani/client/msg
import kaniwani/client/route.{type Route, Home, Lesson, LogOut}
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn view(current_route: Route) -> element.Element(msg.Msg) {
  let nav_items = [Home, Lesson, LogOut]

  html.nav(
    [attribute.class("p-2 bg-white shadow-md")],
    list.map(nav_items, fn(route) {
      html.a(
        [
          attribute.href(route.to_path_string(route)),
          attribute.class("mx-1 p-1"),
          attribute.classes([
            #("border-b-2 border-blue-500", route == current_route),
          ]),
        ],
        [html.text(route.to_page_name(route))],
      )
    }),
  )
}
