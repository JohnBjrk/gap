import gleam/io
import gleam/string
import gleam/list
import gleam/int
import gleeunit
import gleeunit/should
import gleam_community/ansi
import gap/styling.{
  All, Part, from_comparison, highlight, mk_generic_serializer, no_highlight,
  serialize, to_styled_comparison,
}
import gap.{compare_lists, compare_strings, to_styled}
import gap/comparison.{ListComparison, Match, NoMatch, StringComparison}
import gap/styled_comparison.{StyledComparison}

pub fn main() {
  gleeunit.main()
}

pub type TestType {
  TestType(str: String, int: Int)
}

pub type Warning {
  Please
  Mind
  The(what: String)
}

pub fn performance_2_test() {
  let data = #(
    "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua",
    "lorem ipsum dolor sit amet consectetur bdipiscing elit sed do eiusmod tempor incididunt ut babore et dolore magna aliqua lorem ipsum dolor sit amet bonsectetur bdipbscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur bdipiscing elit sed do eiusmod tempor incididunt ut babore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua",
  )
  compare_strings(data.0, data.1)
}

pub fn performance_test() {
  let list1 =
    list.range(0, 249)
    |> list.map(int.to_string)
  let list2 =
    list.range(0, 232)
    |> list.map(int.to_string)

  io.println("Comparing lists")
  compare_lists(list1, list2)
  io.println("Comparing strings")
  compare_strings(
    list1
    |> string.join(""),
    list2
    |> string.join(""),
  )
}

pub fn compare_strings_test() {
  compare_strings(
    "a test stirng with some letters",
    "and another string with more letters",
  )
  |> should.equal(StringComparison(
    [
      Match(["a", " ", "t", "e"]),
      NoMatch(["s", "t"]),
      Match([" ", "s", "t", "i"]),
      NoMatch(["r"]),
      Match(["n", "g", " ", "w", "i", "t", "h", " "]),
      NoMatch(["s"]),
      Match(["o"]),
      NoMatch(["m"]),
      Match(["e", " ", "l", "e", "t", "t", "e", "r", "s"]),
    ],
    [
      Match(["a"]),
      NoMatch(["n", "d"]),
      Match([" "]),
      NoMatch(["a", "n", "o"]),
      Match(["t"]),
      NoMatch(["h"]),
      Match(["e"]),
      NoMatch(["r"]),
      Match([" ", "s", "t"]),
      NoMatch(["r"]),
      Match(["i", "n", "g", " ", "w", "i", "t", "h", " "]),
      NoMatch(["m"]),
      Match(["o"]),
      NoMatch(["r"]),
      Match(["e", " ", "l", "e", "t", "t", "e", "r", "s"]),
    ],
  ))

  compare_strings(
    "a long string with some small diffs",
    "a lon string with some snall diff",
  )
  |> should.equal(StringComparison(
    [
      Match(["a", " ", "l", "o", "n"]),
      NoMatch(["g"]),
      Match([
        " ", "s", "t", "r", "i", "n", "g", " ", "w", "i", "t", "h", " ", "s",
        "o", "m", "e", " ", "s",
      ]),
      NoMatch(["m"]),
      Match(["a", "l", "l", " ", "d", "i", "f", "f"]),
      NoMatch(["s"]),
    ],
    [
      Match([
        "a", " ", "l", "o", "n", " ", "s", "t", "r", "i", "n", "g", " ", "w",
        "i", "t", "h", " ", "s", "o", "m", "e", " ", "s",
      ]),
      NoMatch(["n"]),
      Match(["a", "l", "l", " ", "d", "i", "f", "f"]),
    ],
  ))
}

pub fn compare_lists_test() {
  compare_lists([1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
  |> should.equal(ListComparison(
    [Match([1]), NoMatch([2]), Match([3, 4, 5])],
    [Match([1, 3, 4, 5]), NoMatch([6])],
  ))
}

pub fn compare_lists_custom_type_test() {
  compare_lists(
    [TestType("one", 1), TestType("two", 2), TestType("four", 4)],
    [TestType("one", 1), TestType("three", 3), TestType("four", 4)],
  )
  |> should.equal(ListComparison(
    [
      Match([TestType("one", 1)]),
      NoMatch([TestType("two", 2)]),
      Match([TestType("four", 4)]),
    ],
    [
      Match([TestType("one", 1)]),
      NoMatch([TestType("three", 3)]),
      Match([TestType("four", 4)]),
    ],
  ))
}

pub fn styled_comparison_test() {
  compare_lists([1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
  |> from_comparison()
  |> highlight(
    fn(item) { ">" <> item <> "<" },
    fn(item) { "#" <> item <> "#" },
    no_highlight,
  )
  |> to_styled_comparison()
  |> should.equal(StyledComparison("[1, >2<, 3, 4, 5]", "[1, 3, 4, 5, #6#]"))
}

pub fn styled_comparison_serializer_test() {
  compare_lists([1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
  |> from_comparison()
  |> highlight(
    fn(item) { ">" <> item <> "<" },
    fn(item) { "#" <> item <> "#" },
    no_highlight,
  )
  |> serialize(mk_generic_serializer(
    " :: ",
    fn(all) { "--> " <> all <> " <--" },
  ))
  |> to_styled_comparison()
  |> should.equal(StyledComparison(
    "--> 1 :: >2< :: 3 :: 4 :: 5 <--",
    "--> 1 :: 3 :: 4 :: 5 :: #6# <--",
  ))
}

pub fn demo() {
  let comparison =
    compare_strings(
      "a test stirng with some letters",
      "and another string with more letters",
    )
    |> to_styled()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")
  let comparison =
    compare_strings("the first string", "the fist string")
    |> to_styled()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")
  let comparison =
    compare_strings(
      "a long string with some small diffs",
      "a lon string with some snall diff",
    )
    |> to_styled()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_lists([1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
    |> io.debug()
    |> from_comparison()
    |> highlight(
      fn(item) { ansi.underline(ansi.magenta(item)) },
      fn(item) { ansi.cyan(item) },
      no_highlight,
    )
    |> to_styled_comparison()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_lists([1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
    |> from_comparison()
    |> highlight(
      fn(item) { ansi.underline(ansi.magenta(item)) },
      fn(item) { ansi.cyan(item) },
      no_highlight,
    )
    |> serialize(mk_generic_serializer(
      " and ",
      fn(all) { "Comparison(" <> all <> ")" },
    ))
    |> to_styled_comparison()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_lists(
      [TestType("one", 1), TestType("two", 2), TestType("four", 4)],
      [TestType("one", 1), TestType("three", 3), TestType("four", 4)],
    )
    |> to_styled()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_strings(
      "lucy in the sky with diamonds",
      "lucy is  the spy with diagrams",
    )
    |> to_styled()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  compare_lists([Mind, The("Gap")], [Please, Mind, The("What")])

  // |> io.debug()
  io.println("")

  let comparison =
    compare_strings(
      "Strings are made of smaller things",
      "Things are maybe smaller string",
    )
    |> from_comparison()
    |> highlight(
      fn(first) { ansi.cyan(first) },
      fn(second) { ansi.magenta(second) },
      fn(matching) { matching },
    )
    |> to_styled_comparison()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_lists(["one", "two", "three"], ["two", "two", "tree"])
    |> from_comparison()
    |> highlight(
      fn(first) { first <> " was not found in other" },
      fn(second) { second <> " was not found in other" },
      fn(matching) { matching <> " was found in other" },
    )
    |> serialize(mk_generic_serializer(
      ", and ",
      fn(result) { "Comparing the lists gave the following result: " <> result },
    ))
    |> to_styled_comparison()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")

  let comparison =
    compare_lists(
      [
        "pub type Gap = List(EmptyString)", "", "pub type Traveler {",
        "  OnTrain", "  OverGap(gap: Gap)", "  OnPlatform", "}",
      ],
      [
        "pub type Traveler {", "  OnTrain", "  OverGap(gap: String)",
        "  OnPlatform", "}",
      ],
    )
    |> from_comparison()
    |> highlight(
      fn(first) { "+" <> first },
      fn(second) { "-" <> second },
      fn(matching) { " " <> matching },
    )
    |> serialize(fn(part) {
      case part {
        Part(acc, lines, highlight) ->
          acc <> {
            lines
            |> list.map(fn(line) { highlight(line) })
            |> string.join("\n")
          } <> "\n"
        All(result) -> result
      }
    })
    |> to_styled_comparison()
  io.println(comparison.first)
  io.println(comparison.second)
  io.println("")
}
