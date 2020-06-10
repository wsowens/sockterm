port module Main exposing (..)

import Array
import Browser
import Browser.Dom as Dom
import Html exposing (div, h1, h2, a, textarea, text)
import Html.Attributes as Attr exposing (class, id)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Task


import ANSI exposing (defaultFormat)

-- MAIN

main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- PORTS

port connectSocket : String -> Cmd msg
port writeSocket : String -> Cmd msg

port openSocket : (() -> msg) -> Sub msg
port msgSocket : (String -> msg) -> Sub msg
port closeSocket : (Int -> msg) -> Sub msg

-- MODEL
type alias Model =
  { status : Connection
  , log : Array.Array (Html.Html Msg)
  , format : Maybe ANSI.Format
  }

type Connection
  = Open
  | Connecting
  | Closed

{-| Handle an ANSI-escaped message. Produce a model with an updated list
of messages and updated format state.
-}
processSocketMsg : String -> Model -> Model
processSocketMsg message model =
  processBuffer (ANSI.parseEscaped model.format message) model


{- Update model according to the contents of an ANSI.Buffer -}
processBuffer : ANSI.Buffer Msg -> Model -> Model
processBuffer buf model =
  let new_msgs = Array.fromList buf.nodes in
  { model | format = buf.format, log = Array.append model.log new_msgs }


{-| Display a formatted string in the terminal emulator. -}
formatString : ANSI.Format -> String -> Model -> Model
formatString fmt msg model =
  let formatted = ANSI.format fmt msg in
  { model | log = Array.push formatted model.log }

userEcho : String -> Model -> Model
userEcho = formatString echoFormat

{- The user echo messages are gray and italic. -}
echoFormat : ANSI.Format
echoFormat =
  { defaultFormat | foreground = ANSI.BrightBlack, italic = True }


conFormat : ANSI.Format
conFormat =
  { defaultFormat | foreground = ANSI.BrightBlue, italic = True }


errFormat : ANSI.Format
errFormat =
  { defaultFormat | foreground = ANSI.Red, italic = True }

{- Add an error / closing message based on an error close. -}
closeMessage : Int -> Model -> Model
closeMessage code model =
  let
    err_msg = case code of
      1015 -> "Host not recognized. (1015)\n"
      1006 -> "Connection closed. (1006)\n"
      _ -> "Unknown error. (" ++ (String.fromInt code) ++ ")\n"
    updated = formatString errFormat err_msg model
  in
  { updated | status = Closed }


-- INIT
init : () -> (Model, Cmd Msg)
init flags =
  ( Model Closed Array.empty (Just defaultFormat), Cmd.none)


-- UPDATE
type Msg
  = UserInput String
  | UserConnect String
  | SocketOpen
  | SocketMsg String
  | SocketClose Int
  | Scroll

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UserInput s ->
      let usermsg = s ++ "\n" in
      ( userEcho usermsg model
      , writeSocket usermsg
      )
    UserConnect address ->
      let
        con_msg = "Connecting to: [" ++ address ++ "]...\n"
        updated = formatString conFormat con_msg model
      in
      ( { updated | status = Connecting }
      , connectSocket address
      )
    SocketMsg message ->
      ( processSocketMsg message model
      , scrollChat "term-output"
      )
    SocketOpen ->
      let updated = formatString conFormat "Connected!\n" model in
      ( { updated | status = Open }
      , Cmd.none
      )
    SocketClose code ->
      ( closeMessage code model
      , Cmd.none
      )
    Scroll -> (model, Cmd.none)

{-
  function for scrolling the terminal down
  scrolls occurs if terminal is 50% below the bottom
-}
scrollChat : String -> Cmd Msg
scrollChat id =
  Dom.getViewportOf id
    |> Task.andThen (\info ->
      let
          _ = Debug.log "info" info
          totalHeight = info.scene.height
          offset = info.viewport.y
          height = info.viewport.height
      in
      if (totalHeight - offset - height) / height < 0.5 then
        Dom.setViewportOf id 0 info.scene.height
      else
        Task.succeed ()
    )
    |> Task.attempt (always Scroll)

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
    div [ class "term" ]
      [ div [ class "term-element"]
        [ div [id "term-url-bar"]
          [ text "Connected to:"
          , Html.input [id "term-url-input", Attr.spellcheck False,
              Attr.placeholder "ws://server-domain.com:port", handleTermUrl] []
          , statusIcon model.status ]
        ]
      , div [ class "term-element", id "term-output"] (Array.toList model.log)
      , textarea [ class "term-element", id "term-input", Attr.spellcheck False,
        Attr.placeholder "Type a command here. Press [Enter] to submit.",
        handleTermInput, Attr.value "" ] []
      ]

statusIcon : Connection -> Html.Html msg
statusIcon status =
  case status of
    Open -> text "[CONNECTED]"
    Connecting -> text "[CONNECTING...]"
    Closed ->  text "[CLOSED]"


-- EVENT HANDLERS

handleTermUrl : Html.Attribute Msg
handleTermUrl =
  eventDecoder
  |> Decode.andThen checkEnter
  |> Decode.map (\v -> (UserConnect v, False) )
  |> Events.stopPropagationOn "keypress"


handleTermInput : Html.Attribute Msg
handleTermInput =
  eventDecoder
  |> Decode.andThen checkEnterShift
  |> Decode.map (\v -> ( UserInput v, False) )
  |> Events.stopPropagationOn "keypress"


checkEnterShift: Event -> Decoder String
checkEnterShift e =
  if e.key == 13 then
    if e.shift then
      Decode.fail "Shift key pressed with enter"
    else
      Events.targetValue
  else
    Decode.fail "Shift key pressed with enter"


checkEnter: Event -> Decoder String
checkEnter e =
  if e.key == 13 then
    Events.targetValue
  else
    Decode.fail "Shift key pressed with enter"


type alias Event =
  { shift : Bool
  , key : Int
  }


eventDecoder : Decoder Event
eventDecoder =
  Decode.map2 Event
    (Decode.field "shiftKey" Decode.bool)
    (Decode.field "keyCode" Decode.int)
