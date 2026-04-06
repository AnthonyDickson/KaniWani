import gleam/option.{None}
import kaniwani/client/msg.{type Msg}
import kaniwani/client/route.{type Route}
import lustre/effect.{type Effect}
import modem

pub fn navigate_to(route: Route) -> Effect(Msg) {
  modem.push(route.to_path_string(route), None, None)
}
