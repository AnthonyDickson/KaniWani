import gleam/json

pub type Token {
  Token(user_id: Int)
}

pub fn to_json(token: Token) {
  json.object([
    #("user_id", json.int(token.user_id)),
  ])
}
