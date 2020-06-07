module Color exposing (Format, Color, parseANSI, parseANSIwithError, defaultFormat)
import Html
import Html.Attributes as Attributes

import Parser exposing (..)
import Set
import Debug

{- 
  token from a stream of data with ANSI escape values
  See: https://en.wikipedia.org/wiki/ANSI_escape_code
  (Note, only the SGR command is supported)
-}
type AnsiToken
  = Content String  -- a normal bit of text to be formatted
  | SGR (List Int)  -- 'set graphics rendition'

--the CSI command, ESC + [
csi = '\u{001b}'

content : Parser AnsiToken
content =
  succeed Content
  |= variable
    { start = (/=) csi
    , inner = (/=) csi
    , reserved = Set.empty
    }

-- may need to remake this to support better error messages
sgr : Parser AnsiToken
sgr =
  succeed SGR
  |= sequence
    { start = "\u{001b}["
    , separator = ";"
    , end = "m"
    , spaces = succeed ()
    , item = int
    , trailing = Forbidden
    }

ansiToken : Parser (List AnsiToken)
ansiToken =
  sequence
  { start = ""
  , separator = ""
  , end = ""
  , item = oneOf [ sgr, content ]
  , spaces = succeed ()
  , trailing = Optional
  }

run = Parser.run
test = "\u{001b}[31mmeme\u{001b}[0m"


type alias Format =
  { foreground : Color
  }

defaultFormat = Format Default

type Color
  = Black
  | Red
  | Green
  | Yellow
  | Blue
  | Magenta
  | Cyan
  | White
  | Default

type ColorType
  = Background
  | Foreground

colorName : Color -> Maybe String
colorName color =
  case color of
    Black   -> Just "black"
    Red     -> Just "red"
    Green   -> Just "green"
    Yellow  -> Just "yellow"
    Blue    -> Just "blue"
    Magenta -> Just "magenta"
    Cyan    -> Just "cyan"
    White   -> Just "white"
    _ -> Nothing

colorAttr : Color -> ColorType -> Maybe (Html.Attribute msg)
colorAttr color cType =
  -- is there a simple string representation?
  -- TODO: handle backgrounds
  case (colorName color) of
    Just str -> 
      case cType of
        Foreground -> Just <| Attributes.class ("term-" ++ str)
        Background -> Just <| Attributes.class ("term-" ++ str ++ "-bg")
    Nothing -> Nothing

format : Format -> String -> Html.Html msg
format fmt cntnt =
  let
    attributes = []
      |> (::) (colorAttr fmt.foreground Foreground)
      |> List.filterMap identity
  in
  Html.span attributes [Html.text cntnt]

handleSGR : Int -> Format -> Format
handleSGR code fmt =
  case code of
    0 -> defaultFormat
    30 -> {fmt | foreground = Black }
    31 -> {fmt | foreground = Red }
    32 -> {fmt | foreground = Green }
    33 -> {fmt | foreground = Yellow }
    34 -> {fmt | foreground = Blue }
    35 -> {fmt | foreground = Magenta }
    36 -> {fmt | foreground = Cyan }
    37 -> {fmt | foreground = White }
    39 -> {fmt | foreground = Default }
    _ -> fmt
  
type alias Buffer msg =
  { completed : List (Html.Html msg)
  , format : Maybe Format
  }

handleToken : AnsiToken -> Buffer msg -> Buffer msg
handleToken token buf =
  case token of
    SGR codes ->
      case buf.format of
        Just fmt ->
          { buf | format = Just <| Debug.log "sgr: " (List.foldl handleSGR fmt codes) }
        -- if we aren't doing the format thing, then just ignore the SGR
        Nothing -> buf
    Content cntent ->
        let fmt = Maybe.withDefault defaultFormat buf.format in
        { buf | completed = (format fmt cntent) :: buf.completed }


handleTokens : Maybe Format -> List AnsiToken -> (Maybe Format, List (Html.Html msg))
handleTokens current tokens =
  let 
    buf = Buffer [] current 
    updated = List.foldl handleToken buf tokens
  in
  (updated.format, List.reverse updated.completed)

parseANSI : Maybe Format -> String -> Result (List Parser.DeadEnd) (Maybe Format, List (Html.Html msg))
parseANSI fmt data =
  Result.map (handleTokens fmt) (Parser.run ansiToken data)

-- parse an ANSI stream and convert any underlying error messages into Html nodes
parseANSIwithError : Maybe Format -> String -> (Maybe Format, List (Html.Html msg))
parseANSIwithError fmt data =
  case (parseANSI fmt data) of
    Err (deadEnd) -> (fmt , [ Html.text (Parser.deadEndsToString deadEnd) ])
    Ok value -> value