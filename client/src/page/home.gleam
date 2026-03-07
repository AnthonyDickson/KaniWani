import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import rsvp

import api_route.{Groceries}
import auth
import error_view
import groceries.{type GroceryItem, GroceryItem}
import json_helpers
import model.{type Model, Authenticated, LoadingPage}
import msg.{
  type HomeMsg, type Msg, HomeMsg, ServerLoadedList, ServerSavedList,
  UserAddedItem, UserSavedList, UserTypedNewItem, UserUpdatedQuantity,
}
import route.{Home}
import rsvp_helpers

pub fn update(model: Model, msg: HomeMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    Authenticated(..), UserSavedList -> #(
      Authenticated(..model, saving: True),
      save_list(model.items) |> effect.map(HomeMsg),
    )

    Authenticated(..), ServerSavedList(Ok(_)) -> #(
      Authenticated(..model, saving: False, error: None),
      effect.none(),
    )

    LoadingPage(_, target_route), ServerLoadedList(Ok(response)) -> {
      let items = json.parse(response.body, groceries.grocery_list_decoder())
      let #(items, error) = case items {
        Ok(items) -> #(items, None)
        Error(error) -> #([], Some(json_helpers.describe_error(error)))
      }
      #(
        Authenticated(target_route, items:, new_item: "", saving: False, error:),
        modem.push(route.to_path_string(Home), None, None),
      )
    }

    Authenticated(..), ServerSavedList(Error(error)) -> {
      use <- auth.auto_logout(error)
      #(
        Authenticated(
          ..model,
          saving: False,
          error: Some("Failed to save list"),
        ),
        effect.none(),
      )
    }

    Authenticated(..), ServerLoadedList(Error(error)) -> #(
      Authenticated(
        ..model,
        saving: False,
        error: Some(rsvp_helpers.describe_error(error)),
      ),
      modem.push(route.to_path_string(Home), None, None),
    )

    Authenticated(..), UserAddedItem -> {
      case model.new_item {
        "" -> #(model, effect.none())
        name -> {
          let item = GroceryItem(name:, quantity: 1)
          let updated_items = list.append(model.items, [item])

          #(
            Authenticated(..model, items: updated_items, new_item: ""),
            effect.none(),
          )
        }
      }
    }

    Authenticated(..), UserTypedNewItem(text) -> #(
      Authenticated(..model, new_item: text),
      effect.none(),
    )

    Authenticated(..), UserUpdatedQuantity(index:, quantity:) -> {
      let updated_items =
        list.index_map(model.items, fn(item, item_index) {
          case item_index == index {
            True -> GroceryItem(..item, quantity:)
            False -> item
          }
        })

      #(Authenticated(..model, items: updated_items), effect.none())
    }
    _, _ -> #(model, effect.none())
  }
}

pub fn get_list() -> Effect(HomeMsg) {
  let url = api_route.to_string(Groceries)

  rsvp.get(url, rsvp.expect_ok_response(ServerLoadedList))
}

fn save_list(items: List(GroceryItem)) -> Effect(HomeMsg) {
  let body = groceries.grocery_list_to_json(items)
  let url = api_route.to_string(Groceries)

  rsvp.post(url, body, rsvp.expect_ok_response(ServerSavedList))
}

pub fn view(
  items items: List(GroceryItem),
  new_item new_item: String,
  saving saving: Bool,
  error error: Option(String),
) -> Element(Msg) {
  let styles = [
    #("max-width", "30ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  html.div([attribute.styles(styles)], [
    html.h1(
      [attribute.class("text-3xl font-bold underline text-center mt-10")],
      [html.text("Grocery List")],
    ),
    view_grocery_list(items),
    view_new_item(new_item),
    html.div([], [
      html.button(
        [event.on_click(HomeMsg(UserSavedList)), attribute.disabled(saving)],
        [
          html.text(case saving {
            True -> "Saving..."
            False -> "Save List"
          }),
        ],
      ),
    ]),
    error_view.view_error_paragraph(error),
  ])
}

fn view_grocery_list(items: List(GroceryItem)) -> Element(Msg) {
  case items {
    [] -> html.p([], [html.text("No items in your list yet.")])
    _ -> {
      html.ul(
        [],
        list.index_map(items, fn(item, index) {
          html.li([], [view_grocery_item(item, index)])
        }),
      )
    }
  }
}

fn view_grocery_item(item: GroceryItem, index: Int) -> Element(Msg) {
  html.div([attribute.styles([#("display", "flex"), #("gap", "1em")])], [
    html.span([attribute.style("flex", "1")], [html.text(item.name)]),
    html.input([
      attribute.style("width", "4em"),
      attribute.type_("number"),
      attribute.value(int.to_string(item.quantity)),
      attribute.min("0"),
      event.on_input(fn(value) {
        int.parse(value)
        |> result.unwrap(0)
        |> fn(quantity) { HomeMsg(UserUpdatedQuantity(index, quantity:)) }
      }),
    ]),
  ])
}

fn view_new_item(new_item: String) -> Element(Msg) {
  html.div([], [
    html.input([
      attribute.placeholder("Enter item name"),
      attribute.value(new_item),
      event.on_input(fn(input) { HomeMsg(UserTypedNewItem(input)) }),
    ]),
    html.button([event.on_click(HomeMsg(UserAddedItem))], [html.text("Add")]),
  ])
}
