module ANSI exposing
  ( Format, defaultFormat, format, Color(..), Buffer, parseEscaped)
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



-- PARSERS

{- The CSI command, ESC + [ -}
csi = '\u{001b}'


{- For parsing non-escaped, regular content -}
content : Parser AnsiToken
content =
  succeed Content
  |= variable
    { start = (/=) csi
    , inner = (/=) csi
    , reserved = Set.empty
    }


{- For parsing the parameters of an SGR command, i.e. "\u{001b}[4;31m" -}
sgr : Parser AnsiToken
sgr =
  succeed SGR
  |= sequence
    { start = "\u{001b}["
    , separator = ";"
    , end = "m"
    , spaces = succeed () -- no characters are considered 'spaces'
    , item = int
    , trailing = Forbidden
    }


{- complete parser for a stream of ANSI tokens -}
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

-- FORMATTING

{-| Struct representing the Format state of a terminal emulator. This struct
stores the foreground, background, and several decoration attributes (bold,
italics, underline, etc.)
-}
type alias Format =
  { foreground : Color
  , background : Color
  , bold : Bool
  , italic : Bool
  , underline : Bool
  , strike : Bool
  , blink : Bool
  , reverse : Bool
  }


{- The default Format for text. -}
defaultFormat : Format
defaultFormat =
  { foreground = Default
  , background = Default
  , bold = False
  , italic = False
  , underline = False
  , strike = False
  , blink = False
  , reverse = False
  }


{-| Type representing the color of text.
Currently, the basic 8 colors are supported (for SGR codes 30-37 and 40-47) as
well as the 8 nonstandard bright colors (for SGR codes 90-97 and 100-107).
-}
type Color
  -- basic colors
  = Black
  | Red
  | Green
  | Yellow
  | Blue
  | Magenta
  | Cyan
  | White
  | Default
  -- nonstandard bright colors
  | BrightBlack
  | BrightRed
  | BrightGreen
  | BrightYellow
  | BrightBlue
  | BrightMagenta
  | BrightCyan
  | BrightWhite

{- Apply a format to a string of content, producing an HTML node. -}
format : Format -> String -> Html.Html msg
format fmt cntnt =
  let
    (foreground, background) =
      if fmt.reverse then
        -- reverse colors if fmt.reverse flag is enabled
        ( colorAttr fmt.background Foreground,
          colorAttr fmt.foreground Background)
      else
        ( colorAttr fmt.foreground Foreground,
          colorAttr fmt.background Background)
    attributes = []
      |> (::) foreground
      |> (::) background
      |> (++) (decorationAttr fmt)
      |> List.filterMap identity
  in
  Html.span attributes [Html.text cntnt]


{-| Extract a list of CSS classes based on a Format's decoration attributes. -}
decorationAttr : Format -> List (Maybe (Html.Attribute msg))
decorationAttr fmt =
  {-
    Both underline and strikethrough rely on the 'text-decoration' CSS property.
    So we have to handle these as a special case.
  -}
  if fmt.strike && fmt.underline
  then
    [ Just (Attributes.class "term-underline-strike") ]
    |> (::) ( maybeIf fmt.bold (Attributes.class "term-bold") )
    |> (::) ( maybeIf fmt.italic (Attributes.class "term-italic") )
    |> (::) ( maybeIf fmt.blink (Attributes.class "term-blink") )
    |> (::) ( maybeIf fmt.reverse (Attributes.class "term-reverse") )
  else
    []
    |> (::) ( maybeIf fmt.bold (Attributes.class "term-bold") )
    |> (::) ( maybeIf fmt.italic (Attributes.class "term-italic") )
    |> (::) ( maybeIf fmt.underline (Attributes.class "term-underline") )
    |> (::) ( maybeIf fmt.blink (Attributes.class "term-blink") )
    |> (::) ( maybeIf fmt.reverse (Attributes.class "term-reverse") )
    |> (::) ( maybeIf fmt.strike (Attributes.class "term-strike") )

maybeIf : Bool -> item -> Maybe item
maybeIf condition item = if condition then Just item else Nothing


{-| Get a string representation of a Color. (This used for assigning CSS
classes to formatted HTML.
-}
colorName : Color -> Maybe String
colorName color =
  case color of
    -- the basic colors
    Black   -> Just "black"
    Red     -> Just "red"
    Green   -> Just "green"
    Yellow  -> Just "yellow"
    Blue    -> Just "blue"
    Magenta -> Just "magenta"
    Cyan    -> Just "cyan"
    White   -> Just "white"
    -- the nonstandard bright colors, often not supported
    BrightBlack   -> Just "bright-black"
    BrightRed     -> Just "bright-red"
    BrightGreen   -> Just "bright-green"
    BrightYellow  -> Just "bright-yellow"
    BrightBlue    -> Just "bright-blue"
    BrightMagenta -> Just "bright-magenta"
    BrightCyan    -> Just "bright-cyan"
    BrightWhite   -> Just "bright-white"
    _ -> Nothing


{-| Generate the correct Html attribute for text of this color. -}
colorAttr : Color -> ScenePart -> Maybe (Html.Attribute msg)
colorAttr color cType =
  -- is there a simple string representation?
  -- TODO: handle backgrounds
  case (colorName color) of
    Just str ->
      case cType of
        Foreground -> Just <| Attributes.class ("term-" ++ str)
        Background -> Just <| Attributes.class ("term-" ++ str ++ "-bg")
    Nothing -> Nothing

{-| A simple type for background / foreground, used in function above -}
type ScenePart
  = Background
  | Foreground


-- PROCESSING

{-| Update the format based on the given SGR parameter.
This function contains the core logic of this table:
https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
-}
handleSGR : Int -> Format -> Format
handleSGR param fmt =
  case param of
    -- clear decoration
    0 -> defaultFormat
    -- text decoration on
    1 -> { fmt | bold = True }
    3 -> { fmt | italic = True }
    4 -> { fmt | underline = True }
    {-
      for the sake of simplicity, we don't distinguish
      between slow vs. fast blink
    -}
    5 -> { fmt | blink = True }
    6 -> { fmt | blink = True }
    7 -> { fmt | reverse = True }
    9 -> { fmt | strike = True }
    -- text decoration off
    21 -> { fmt | bold = False }
    23 -> { fmt | italic = False }
    24 -> { fmt | underline = False }
    27 -> { fmt | reverse = False }
    29 -> { fmt | strike = False }
    -- foreground coloring
    30 -> { fmt | foreground = Black }
    31 -> { fmt | foreground = Red }
    32 -> { fmt | foreground = Green }
    33 -> { fmt | foreground = Yellow }
    34 -> { fmt | foreground = Blue }
    35 -> { fmt | foreground = Magenta }
    36 -> { fmt | foreground = Cyan }
    37 -> { fmt | foreground = White }
    38 -> fmt -- placeholder
    39 -> { fmt | foreground = Default }
    -- background colors
    40 -> { fmt | background = Black }
    41 -> { fmt | background = Red }
    42 -> { fmt | background = Green }
    43 -> { fmt | background = Yellow }
    44 -> { fmt | background = Blue }
    45 -> { fmt | background = Magenta }
    46 -> { fmt | background = Cyan }
    47 -> { fmt | background = White }
    48 -> fmt -- placeholder
    49 -> { fmt | background = Default }
    -- bright foreground colors (nonstandard)
    90 ->  { fmt | foreground = BrightBlack }
    91 ->  { fmt | foreground = BrightRed }
    92 ->  { fmt | foreground = BrightGreen }
    93 ->  { fmt | foreground = BrightYellow }
    94 ->  { fmt | foreground = BrightBlue }
    95 ->  { fmt | foreground = BrightMagenta }
    96 ->  { fmt | foreground = BrightCyan }
    97 ->  { fmt | foreground = BrightWhite }
    -- bright background colors (nonstandard)
    100 -> { fmt | background = BrightBlack }
    101 -> { fmt | background = BrightRed }
    102 -> { fmt | background = BrightGreen }
    103 -> { fmt | background = BrightYellow }
    104 -> { fmt | background = BrightBlue }
    105 -> { fmt | background = BrightMagenta }
    106 -> { fmt | background = BrightCyan }
    107 -> { fmt | background = BrightWhite }
    _ -> fmt

{-
  A Format.Buffer contains a stack of processed HTML nodes and possibly a
  Format state. If `Nothing` is provided for the format state, then no formats
  will be stored in the Buffer and all SGR commands will be ignored.
-}
type alias Buffer msg =
  { nodes : List (Html.Html msg)
  , format : Maybe Format
  }


{-
  Update Buffer according to a single ANSI token.
  If content is provided, then content will be formatted and added to the
  buffer's stack of nodes. If an SGR command is provided, then the Buffer's
  current format state will be updated.
-}
consumeToken : AnsiToken -> Buffer msg -> Buffer msg
consumeToken token buf =
  case token of
    SGR codes ->
      case buf.format of
        Just fmt ->
          { buf | format = Just ( List.foldl handleSGR fmt codes ) }
        -- if we aren't doing the format thing, then just ignore the SGR
        Nothing -> buf
    Content cntent ->
        let fmt = Maybe.withDefault defaultFormat buf.format in
        { buf | nodes = (format fmt cntent) :: buf.nodes }


{-| Process a stream tokens, returning a Buffer with the final format state
and a list of formatted HTML nodes (in FIFO order).
-}
processTokens : Maybe Format -> List AnsiToken -> Buffer msg
processTokens start_fmt tokens =
  let start_buf = Buffer [] start_fmt
      updated_buf = List.foldl consumeToken start_buf tokens
  in
  { updated_buf | nodes = List.reverse updated_buf.nodes }


{-| Parse and process a stream of ANSI-escaped data.
Optionally, a starting Format state may be provided.  If `Nothing` is provided,
all SGR commands will be ignored. (Provide `Just defaultFormat` to enable
formatting but start with the default Format state.)
-}
parseEscaped : Maybe Format -> String -> Buffer msg
parseEscaped fmt data =
  case (Parser.run ansiToken data) of
    Err (deadEnd) -> Buffer [ Html.text (Parser.deadEndsToString deadEnd) ] fmt
    Ok tokens -> processTokens fmt tokens