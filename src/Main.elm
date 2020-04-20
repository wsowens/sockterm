module Main exposing (..)

import Browser
import Html exposing (div, h1, textarea, text)
import Html.Attributes exposing (class, style, id, spellcheck, placeholder)

-- MAIN

main = 
    Browser.document
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

-- MODEL
type alias Model =
    { msgs : List String
    , host : Maybe String
    }


-- INIT
init : () -> (Model, Cmd Msg)
init _ =
    ({ msgs = [], host = Nothing }
    , Cmd.none
    )


-- UPDATE
type Msg
    = Input String

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Input s ->
            ( { model | msgs = s :: model.msgs },
                Cmd.none
            )


-- SUBSCRIPTIONS
subscriptions _ = Sub.none


-- VIEW

view : Model -> Browser.Document Msg
view model = 
    { title = "Web Term"
    , body = 
        [ Html.h1 [] [Html.text "Hello world."]
        , div [ class "term-outer"]
            [ div [ class "term" ] 
                [ div [ class "term-element", style "height" "calc(100% - 2.0em)" ]
                    [ div [ id "term-output"] [ text "Welcome to WebTerm!" ] ]
                , div [ class "term-element"] 
                    [ textarea [ id "term-input", spellcheck False, 
                        placeholder "Type a command here. Press [Enter] to submit."] []
                    ]
                ]
            ]
        ]
    }