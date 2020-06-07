port module Main exposing (..)

import Array
import Browser
import Html exposing (div, h1, h2, a, textarea, text)
import Html.Attributes as Attr exposing (class, id)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Browser.Navigation as Nav
import Url

import Color

-- MAIN

main = 
  Browser.application
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    , onUrlChange = UrlChange
    , onUrlRequest = LinkClick
    }


-- PORTS

port connectSocket : String -> Cmd msg
port writeSocket : String -> Cmd msg

port openSocket : (() -> msg) -> Sub msg
port msgSocket : (String -> msg) -> Sub msg
port closeSocket : (Int -> msg) -> Sub msg


-- MODEL
type alias Model =
  { url : Url.Url
  , key : Nav.Key
  , msgs : Array.Array (Html.Html Msg)
  , status : Connection
  , format : Maybe Color.Format
  }

type Connection
  = Open
  | Connecting
  | Closed

-- INIT
init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init flags url key =
  ( Model url key Array.empty Closed (Just Color.defaultFormat), Cmd.none)


-- UPDATE
type Msg
  = UserInput String
  | UserConnect String
  | SocketOpen
  | SocketMsg String
  | SocketClose String
  | UrlChange Url.Url
  | LinkClick Browser.UrlRequest

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UserInput s ->
      -- TODO: scroll!
      let usermsg = s ++ "\n" in
      ( { model | msgs = Array.push (text <| "< " ++ usermsg) model.msgs },
        writeSocket usermsg
      )     
    UserConnect address ->
      ( { model | msgs = Array.push (text <| "Connecting to: [" ++ address ++ "]...\n")  model.msgs, status = Connecting },
        connectSocket address
      )
    SocketMsg message ->
      -- TODO: scroll!
      let
          (newFormat, msgs) = (Color.parseANSIwithError model.format message)
          newMsgs = Array.append model.msgs (Array.fromList msgs)
      in
      ( { model | msgs = newMsgs, format = newFormat},
        Cmd.none
      )
    SocketOpen ->
      ( { model | msgs = Array.push (text "Connected!\n")  model.msgs, status = Open },
        Cmd.none
      )
    SocketClose mesg -> 
      ( { model | msgs = Array.push (text <| mesg ++ "\n") model.msgs, status = Closed },
        Cmd.none
      )
    LinkClick urlRequest ->
      case urlRequest of 
        Browser.Internal url ->
          ( model, Nav.pushUrl model.key (Url.toString url))
        
        Browser.External href ->
          (model, Nav.load href)

    UrlChange url ->
      ( {model | url = url }
      , Cmd.none
      )


-- SUBSCRIPTIONS
subscriptions _ =
  Sub.batch
  [ openSocket (always SocketOpen)
  , msgSocket SocketMsg
  , closeSocket socketCode
  ]
  

socketCode : Int -> Msg
socketCode i =
  SocketClose (case i of
    1015 -> "Host not recognized"
    1006 -> "Connection closed"
    _ -> "Unknown error " ++ (String.fromInt i)
  )


-- VIEW
view : Model -> Browser.Document Msg
view model = 
  { title = "Web Term"
  , body = 
    [ div [ id "navbar" ] 
      [ h1 [class "term-underline-crossedout" ] [text "WebTerm."]
      ] 
    , div [ class "term-outer"]
      [ div [ class "term" ] 
        [ div [ class "term-element"]
          [ div [id "term-url-bar"] 
            [ text "Connected to:"
            , Html.input [id "term-url-input", Attr.spellcheck False, 
                Attr.placeholder "ws://server-domain.com:port", handleTermUrl] []
            , statusIcon model.status ] 
          ]
        , div [ class "term-element", id "term-output"] (Array.toList model.msgs)
        , textarea [ class "term-element", id "term-input", Attr.spellcheck False, 
          Attr.placeholder "Type a command here. Press [Enter] to submit.",
          handleTermInput, Attr.value "" ] []
        ]
      ]
    ]
  }

viewMessages : List String -> List (Html.Html Msg)
viewMessages msgs =
  msgs |> List.reverse |> List.map ( (++) "\n" ) |> List.map text 

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

statusIcon : Connection -> Html.Html msg
statusIcon s =
  case s of
    Open -> text "[CONNECTED]"
    Connecting -> text "CONNECTING..."
    Closed ->  text "[CLOSED]"