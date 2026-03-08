import gleam/option.{None}
import lustre/effect.{type Effect}
import modem

import msg.{type Msg}
import route.{type Route}

pub fn navigate_to(route: Route) -> Effect(Msg) {
  modem.push(route.to_path_string(route), None, None)
}
