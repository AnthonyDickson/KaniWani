import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

import api_route.{Groceries}
import effects/session
import error_view
import groceries.{type GroceryItem, GroceryItem}
import json_helpers
import model.{type Model, HomePage}
import msg.{
  type HomeMsg, type Msg, HomeMsg, ServerLoadedList, ServerSavedList,
  UserAddedItem, UserNavigatedToHomePage, UserSavedList, UserTypedNewItem,
  UserUpdatedQuantity,
}
import navbar
import route.{Home}
import rsvp_helpers

pub fn update(model: Model, msg: HomeMsg) -> #(Model, Effect(Msg)) {
  case model, msg {
    HomePage(..), UserNavigatedToHomePage -> {
      #(model, get_list() |> effect.map(HomeMsg))
    }

    HomePage(..), ServerLoadedList(Ok(response)) -> {
      let items = json.parse(response.body, groceries.grocery_list_decoder())
      let #(items, error) = case items {
        Ok(items) -> #(items, None)
        Error(error) -> #([], Some(json_helpers.describe_error(error)))
      }
      #(
        HomePage(items:, new_item: "", loading: False, saving: False, error:),
        effect.none(),
      )
    }

    HomePage(..), ServerLoadedList(Error(error)) -> {
      use <- session.auto_logout(error)
      #(
        HomePage(
          ..model,
          loading: False,
          saving: False,
          error: Some(rsvp_helpers.describe_error(error)),
        ),
        effect.none(),
      )
    }

    HomePage(..), UserSavedList -> #(
      HomePage(..model, saving: True),
      save_list(model.items) |> effect.map(HomeMsg),
    )

    HomePage(..), ServerSavedList(Ok(_)) -> #(
      HomePage(..model, saving: False, error: None),
      effect.none(),
    )

    HomePage(..), ServerSavedList(Error(error)) -> {
      use <- session.auto_logout(error)
      #(
        HomePage(..model, saving: False, error: Some("Failed to save list")),
        effect.none(),
      )
    }

    HomePage(..), UserAddedItem -> {
      case model.new_item {
        "" -> #(model, effect.none())
        name -> {
          let item = GroceryItem(name:, quantity: 1)
          let updated_items = list.append(model.items, [item])

          #(
            HomePage(..model, items: updated_items, new_item: ""),
            effect.none(),
          )
        }
      }
    }

    HomePage(..), UserTypedNewItem(text) -> #(
      HomePage(..model, new_item: text),
      effect.none(),
    )

    HomePage(..), UserUpdatedQuantity(index:, quantity:) -> {
      let updated_items =
        list.index_map(model.items, fn(item, item_index) {
          case item_index == index {
            True -> GroceryItem(..item, quantity:)
            False -> item
          }
        })

      #(HomePage(..model, items: updated_items), effect.none())
    }
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

fn get_list() -> Effect(HomeMsg) {
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
  loading loading: Bool,
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

  let contents = case loading {
    True -> loading_view(styles)
    False -> loaded_view(styles, items, new_item, saving, error)
  }

  html.div([], [navbar.view(Home), contents])
}

fn loading_view(styles: List(#(String, String))) -> Element(Msg) {
  html.main([attribute.styles(styles)], [
    html.h1(
      [attribute.class("text-3xl font-bold underline text-center mt-10")],
      [html.text("Grocery List")],
    ),
    html.p([], [html.text("Loading..")]),
  ])
}

fn loaded_view(
  styles: List(#(String, String)),
  items: List(GroceryItem),
  new_item: String,
  saving: Bool,
  error: Option(String),
) -> Element(Msg) {
  html.main([attribute.styles(styles)], [
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
