import gleam/http/response.{type Response}

import rsvp.{type Error}

import route.{type Route}

pub type Msg {
  // Auth flow
  ServerLoggedOutUser(Result(Response(String), Error))
  // Routing
  ClientChangedRoute(new_route: Route)
  // Page specific messages
  HomeMsg(HomeMsg)
  LogInMsg(LogInMsg)
  RegisterMsg(RegisterMsg)
}

pub type HomeMsg {
  UserNavigatedToHomePage
  ServerSavedList(Result(Response(String), Error))
  ServerLoadedList(Result(Response(String), Error))
  UserAddedItem
  UserTypedNewItem(String)
  UserSavedList
  UserUpdatedQuantity(index: Int, quantity: Int)
}

pub type LogInMsg {
  UserTypedPassword(String)
  UserCheckedShowPassword(Bool)
  UserSentLogInForm
  ServerAuthenticatedUser(Result(Response(String), Error))
}

pub type RegisterMsg {
  UserTypedRegisterPassword(String)
  UserCheckedShowRegisterPassword(Bool)
  UserSentRegistrationForm
  ServerRegisteredUser(Result(Response(String), Error))
}
