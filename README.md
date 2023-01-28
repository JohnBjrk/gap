# gap

[![Package Version](https://img.shields.io/hexpm/v/gap)](https://hex.pm/packages/gap)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gap/)

A Gleam library for comparing strings/lists and producing a textual (styled) representation of the differences.

A typical styled output from the comparison can look like this:

<img src="https://github.com/JohnBjrk/gap/blob/main/static/example_diff_lucy.png?raw=true" alt="Image of two strings with highlighted differences" width="400vw">

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add gap
```

Documentation can be found at <https://hexdocs.pm/gap>.

## Usage

# Introduction

Gap implements string/list comparison by finding the longest common subsequence. The result of the comparison are two sequences 
(one for each of the compared strings/lists) consisting of subsequences that are annotated as matching or non-matching.

For example comparing the strings in the example above will look as follows:

```gleam
let comparison =
compare_strings(
    "lucy in the sky with diamonds",
    "lucy is  the shy with diagrams",
)
|> io.debug()
// StringComparison(
//   [
//     Match(["l", "u", "c", "y", " ", "i"]),
//     NoMatch(["n"]),
//     Match([" ", "t", "h", "e", " ", "s"]),
//     NoMatch(["k"]),
//     Match(["y", " ", "w", "i", "t", "h", " ", "d", "i", "a", "m"]),
//     NoMatch(["o", "n", "d"]),
//     Match(["s"]),
//   ],
//   [
//     Match(["l", "u", "c", "y", " ", "i"]),
//     NoMatch(["s", " "]),
//     Match([" ", "t", "h", "e", " ", "s"]),
//     NoMatch(["h"]),
//     Match(["y", " ", "w", "i", "t", "h", " ", "d", "i"]),
//     NoMatch(["a", "g", "r"]),
//     Match(["a", "m", "s"]),
//   ],
// )
```

## Styling

This is useful information but a bit overwhelming to look at (specially for longer string) so the library
has some built in functions to display the differences using colors instead.

Using the same example again we can style the result and print it to the console

```gleam
let comparison =
compare_strings(
    "lucy in the sky with diamonds",
    "lucy is  the shy with diagrams",
)
|> to_styled()
io.println(comparison.first)
io.println(comparison.second)
```

This will give us something similar to the output above.

## Comparing list

It is also possible to compare lists with elements of arbitrary types. 

```gleam
pub type Warning {
  Please
  Mind
  The(what: String)
}

compare_lists([Mind, The("Gap")], [Please, Mind, The("What")])
|> io.debug()
// ListComparison(
//   [Match([Mind]), NoMatch([The("Gap")])],
//   [NoMatch([Please]), Match([Mind]), NoMatch([The("What")])],
// )
```

## Customize styling

The visual representation of the comparison can be customized. To do this use a `Styling` created from
the comparison that should be styled. This example uses [gleam_community/ansi](https://hexdocs.pm/gleam_community_ansi/index.html)
to highlight the non-matches in different colors.

```gleam
let comparison =
compare_strings(
    "Strings are made of smaller things",
    "Things are maybe smaller string",
)
|> from_comparison()
|> highlight(
    fn(first) { ansi.cyan(first) },
    fn(second) { ansi.magenta(second) },
)
|> to_styled_comparison()
io.println(comparison.first)
io.println(comparison.second)
```

This will output something similar to this

<img src="https://github.com/JohnBjrk/gap/blob/main/static/example_diff_things.png?raw=true" alt="Image of two strings with highlighted differences" width="400vw">
