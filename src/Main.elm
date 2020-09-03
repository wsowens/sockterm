{-
Copyright 2020 William Owens

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}
port module Main exposing (..)

import Array
import Browser
import Browser.Dom as Dom
import Html exposing (div, h1, h2, a, textarea, text)
import Html.Attributes as Attr exposing (class, id)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Task
-- import packages from wsowens/Term
import Term exposing (Term)
import Term.ANSI as ANSI exposing (defaultFormat)

-- MAIN

main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- PORTS
{- For this Elm application to work, we need to communicate with JS via Ports.
This means that you must write functions for all of these ports on the JS side.
(See 'sockets.js' as an example.)
On the Elm side, notice that all incoming communication uses Subscriptions,
while the outgoing communication uses Commands.

connectSocket is a Cmd to open a new websocket. Upon successful oppening, a
message comes from the openSocket subscription.
writeSocket is the Cmd to write outgoing data to the websocket. msgSocket is a
subscription that captures messages incoming from the websocket.
closeSocket is a subscription that captures error codes if the websocket is
closed (or fails to open).

scrollTerm is a special Cmd that calls some JavaScript to automatically scroll
the term down if a new message is received. (We issue this command after
most update loops.
-}
port connectSocket : String -> Cmd msg
port writeSocket : String -> Cmd msg
port scrollTerm : String -> Cmd msg

port openSocket : (() -> msg) -> Sub msg
port msgSocket : (String -> msg) -> Sub msg
port closeSocket : (Int -> msg) -> Sub msg

-- MODEL
type alias Model =
  { term : Term Msg
  }

{- Convenience function to display a formatted string in the terminal emulator.
-}
printFmt : ANSI.Format -> String -> Term msg -> Term msg
printFmt fmt msg term =
  let formatted = ANSI.format fmt msg in
  { term | log = Array.push formatted term.log }

userEcho : String -> Term msg -> Term msg
userEcho = printFmt echoFormat

{- The user echo messages are gray and italic. -}
echoFormat : ANSI.Format
echoFormat =
  { defaultFormat | foreground = ANSI.BrightBlack, italic = True }

{- Connection messages are blue and italic. -}
conFormat : ANSI.Format
conFormat =
  { defaultFormat | foreground = ANSI.BrightBlue, italic = True }

{- Error messages are red and italic. -}
errFormat : ANSI.Format
errFormat =
  { defaultFormat | foreground = ANSI.Red, italic = True }

{- Add an error / closing message based on an error close. -}
closeMessage : Int -> Term msg -> Term msg
closeMessage code term =
  let
    err_msg = case code of
      1015 -> "Host not recognized. (1015)\n"
      1006 -> "Connection closed. (1006)\n"
      _ -> "Unknown error. (" ++ (String.fromInt code) ++ ")\n"
    updated = printFmt errFormat err_msg term
  in
  { updated | status = Just Term.Closed }


-- INIT
init : () -> (Model, Cmd Msg)
init flags =
  ( Model newTerm , Cmd.none)

{-
A new term uses the default formatting. A user's input from the input box
is captured as a UserInput Msg. The URL submitted from the URL bar is captured
as a UserConnect Msg.
-}
newTerm : Term Msg
newTerm =
  (Term.new (Just Term.Closed) (Just defaultFormat) UserInput UserConnect)

-- UPDATE
type Msg
  = UserInput String
  | UserConnect String
  | SocketOpen
  | SocketMsg String
  | SocketClose Int

--TODO: consider making terminal scrolling automatic?
update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UserInput s ->
      let usermsg = s ++ "\n" in
      ( { model | term = userEcho usermsg model.term }
      , Cmd.batch [ scrollTerm "term-output", writeSocket usermsg ]
      )
    UserConnect address ->
      let
        con_msg = "Connecting to: [" ++ address ++ "]...\n"
        updated = printFmt conFormat con_msg model.term
      in
      ( { model | term = updated }
      , Cmd.batch [ scrollTerm "term-output", connectSocket address ]
      )
    SocketMsg message ->
      ( { model | term = Term.receive message model.term }
      , scrollTerm "term-output"
      )
    SocketOpen ->
      let
        with_msg = printFmt conFormat "Connected!\n" model.term
        updated =
          case (Maybe.withDefault Term.Closed model.term.status) of
          Term.Connecting addr ->
            {with_msg | status = Just (Term.Open addr) }
          -- invalid state!
          _ -> model.term
      in
      ( { model | term = updated }
      , scrollTerm "term-output"
      )
    SocketClose code ->
      let
        updated = closeMessage code model.term
      in
      ( { model | term = updated }
      , scrollTerm "term-output"
      )


-- SUBSCRIPTIONS
subscriptions _ =
  Sub.batch
  [ openSocket (always SocketOpen)
  , msgSocket SocketMsg
  , closeSocket SocketClose
  ]


-- VIEW
view : Model -> Html.Html Msg
view model =
  Term.render model.term
