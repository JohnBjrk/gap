import gleam/option.{None, Option, Some}
import gleam/list
import gleam/string
import gleam_community/ansi
import gap/comparison.{
  Comparison, ListComparison, Match, NoMatch, Segments, StringComparison,
}
import gap/styled_comparison.{StyledComparison}

/// The `Highlighter`takes a string representation of the item that was not matching
/// and should return a string representation that can be used to visually indicate that
/// it is a non-matching item.
///
/// The default implementation of the highlighters uses the `gleam_community/ansi` library
/// to set a different color for the item, but any type if indication can be used as long
/// as it returns a valid string
pub type Highlighter =
  fn(String) -> String

/// `Part` is used to indicate to a custom serializer if it should produce a serialization
/// based on a segment with items or the final string that contains already serialized segments
pub type Part(a) {
  /// `acc` the already serialized part of the result, `part` is the current segment that should be serialized and appended and `highlighter` is the `Highlighter` that can be used to indicate non-matching items
  Part(acc: String, part: List(a), highlight: Highlighter)
  /// `all` is a string representing all serialized segments. This can be useful if some string should be prepended/appended to the final result
  All(all: String)
}

/// A `Serializer`can be used to create string representation of the comparison results
///
/// See [serialize](#serialize) for adding custom serializers and [mk_generic_serializer](#mk_generic_serializer)
pub type Serializer(a) =
  fn(Part(a)) -> String

/// Styling of a `Comparison`
///
/// See [from_comparison](#from_comparison)
pub opaque type Styling(a) {
  Styling(
    comparison: Comparison(a),
    serializer: Option(Serializer(a)),
    first_highlight: Option(Highlighter),
    second_highlight: Option(Highlighter),
  )
}

/// Create a new `Styling` from a `Comparison`
///
/// The `Styling` can be customized by adding highlighters and a serializer
/// See [highlight](#highlight) and [serialize](#serialize)
pub fn from_comparison(comparison: Comparison(a)) -> Styling(a) {
  Styling(comparison, None, None, None)
}

/// Add highlighters to the `Styling`
///
/// The highlighters are used to mark the non-matching items in the
/// first/second list/string
pub fn highlight(
  styling: Styling(a),
  first: Highlighter,
  second: Highlighter,
) -> Styling(a) {
  Styling(
    ..styling,
    first_highlight: Some(first),
    second_highlight: Some(second),
  )
}

/// Add a serializer to the `Styling`
///
/// The serializer is used to create string representation of the items in the segments of the `Comparison`
/// See [Part](#part) for details
///
/// > **NOTE:** `StringComparison` will always use the default string serializer (concatenating the graphemes).
/// > If there is a need for custom serialization of `StringComparison` convert the string to a list of 
/// > graphemes and treat it as a `ListComparison`
pub fn serialize(styling: Styling(a), serializer: Serializer(a)) -> Styling(a) {
  Styling(..styling, serializer: Some(serializer))
}

/// Creates a styled comparison using either custom highlighters/serializer if they where added or default
/// highlighters and/or serializer
pub fn to_styled_comparison(styling: Styling(a)) -> StyledComparison {
  let first_highlight =
    styling.first_highlight
    |> option.unwrap(first_highlight_default)
  let second_highlight =
    styling.second_highlight
    |> option.unwrap(second_highlight_default)
  case styling.comparison {
    StringComparison(first, second) ->
      to_strings(
        first,
        second,
        // NOTE: Using string serializer here because otherwise we need to have a specific string serializer on the styling
        string_serializer,
        first_highlight,
        second_highlight,
      )
    ListComparison(first, second) ->
      to_strings(
        first,
        second,
        option.unwrap(styling.serializer, generic_serializer),
        first_highlight,
        second_highlight,
      )
  }
}

/// Default highlighter for the first string/list in the comparison
pub fn first_highlight_default(string: String) -> String {
  case string {
    " " ->
      string
      |> ansi.underline()
      |> ansi.green()

    _ ->
      string
      |> ansi.green()
      |> ansi.bold()
  }
}

/// Default highlighter for the second string/list in the comparison
pub fn second_highlight_default(string: String) -> String {
  case string {
    " " ->
      string
      |> ansi.underline()
      |> ansi.red()

    _ ->
      string
      |> ansi.red()
      |> ansi.bold()
  }
}

fn no_highlight(string: String) -> String {
  string
}

fn string_serializer(part: Part(String)) -> String {
  case part {
    Part(acc, sequence, highlight) ->
      acc <> {
        sequence
        |> list.map(highlight)
        |> string.join("")
      }
    All(string) -> string
  }
}

fn generic_serializer(part: Part(a)) -> String {
  mk_generic_serializer(", ", fn(all) { "[" <> all <> "]" })(part)
}

/// Creates a generic serializer that uses `separator` between all items and calls
/// `around` for possibility to prepend/append strings to the final result
pub fn mk_generic_serializer(separator: String, around: fn(String) -> String) {
  fn(part) {
    case part {
      Part(acc, sequence, highlight) -> {
        let segment_separator = case acc {
          "" -> ""
          _ -> separator
        }
        acc <> segment_separator <> {
          sequence
          |> list.map(string.inspect)
          |> list.map(highlight)
          |> string.join(separator)
        }
      }
      All(string) -> around(string)
    }
  }
}

fn to_strings(
  first: Segments(a),
  second: Segments(a),
  serializer: Serializer(a),
  first_highlight: Highlighter,
  second_highlight: Highlighter,
) -> StyledComparison {
  let first_styled =
    first
    |> list.fold(
      "",
      fn(str, match) {
        case match {
          Match(item) -> serializer(Part(str, item, no_highlight))
          NoMatch(item) -> serializer(Part(str, item, first_highlight))
        }
      },
    )
  let second_styled =
    second
    |> list.fold(
      "",
      fn(str, match) {
        case match {
          Match(item) -> serializer(Part(str, item, no_highlight))
          NoMatch(item) -> serializer(Part(str, item, second_highlight))
        }
      },
    )

  StyledComparison(
    serializer(All(first_styled)),
    serializer(All(second_styled)),
  )
}
