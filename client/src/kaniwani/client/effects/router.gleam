import gleam/option.{None}
import kaniwani/client/msg.{type Msg}
import kaniwani/client/route.{type Route}
import lustre/effect.{type Effect}
import modem

pub fn navigate(to route: Route) -> Effect(Msg) {
  effect.batch([
    modem.push(route.to_path_string(route), None, None),
    update_title(route),
  ])
}

pub fn replace(with route: Route) -> Effect(Msg) {
  effect.batch([
    modem.replace(route.to_path_string(route), None, None),
    update_title(route),
  ])
}

pub fn update_title(route: Route) -> Effect(Msg) {
  set_title(route.to_page_title(route))
}

fn set_title(title: String) -> Effect(Msg) {
  use _ <- effect.from
  set_title_js(title)
}

@external(javascript, "./router.ffi.mjs", "setTitle")
fn set_title_js(title: String) -> Nil
