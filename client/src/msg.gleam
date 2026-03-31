import gleam/http/response.{type Response}

import rsvp.{type Error}

import route.{type Route}

pub type Msg {
  // Application messages
  ServerLoggedOutUser(Result(Response(String), Error))
  ClientChangedRoute(new_route: Route)
  // Page messages
  HomeMsg(HomeMsg)
  LogInMsg(LogInMsg)
  LessonMsg(LessonMsg)
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

pub type LessonMsg {
  UserNavigatedToLessonPage
}
