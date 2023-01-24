import gleam/io
import gleam/string
import gleam/list
import gleam/map.{Map}
import gleam/result
import gleam/option.{None, Option, Some}
import gleam/int
import gleam/order.{Eq, Gt, Lt}
import gleam/set
import gleam_community/ansi

pub fn main() {
  let #(first, second) =
    compare_strings(
      "a test stirng with some letters",
      "and another string with more letters",
    )
  print_styled(first, second)
  io.println("")
  let #(first, second) = compare_strings("the first string", "the fist string")
  print_styled(first, second)
  io.println("")
  let #(first, second) =
    compare_strings(
      "a long string with some small diffs",
      "a lon string with some snall diff",
    )
  print_styled(first, second)
}

fn print_styled(first, second) {
  let first_styled =
    first
    |> list.fold(
      "",
      fn(str, match) {
        case match {
          Match(seq) -> str <> seq
          NoMatch(seq) -> str <> ansi.bold(ansi.green(seq))
        }
      },
    )
  let second_styled =
    second
    |> list.fold(
      "",
      fn(str, match) {
        case match {
          Match(seq) -> str <> seq
          NoMatch(seq) -> str <> ansi.bold(ansi.red(seq))
        }
      },
    )
  io.println(first_styled)
  io.println(second_styled)
}

type MatchedChar =
  #(#(Int, Int), String)

pub type Match(a) {
  Match(char: a)
  NoMatch(char: a)
}

type Score {
  Score(value: Int, char: Option(String))
}

type StringMap =
  Map(Int, String)

type DiffMap =
  Map(#(Int, Int), Score)

pub fn compare_strings(first: String, second: String) {
  let diff_map =
    second
    |> string.to_graphemes()
    |> list.index_fold(
      map.new(),
      fn(diff_map, char_second, index_second) {
        first
        |> string.to_graphemes()
        |> list.index_fold(
          diff_map,
          fn(diff_map, char_first, index_first) {
            build_diff_map(
              char_first,
              index_first,
              char_second,
              index_second,
              diff_map,
            )
          },
        )
      },
    )
  let tracking =
    back_track(
      diff_map,
      string.length(first) - 1,
      string.length(second) - 1,
      [],
    )
    |> map.from_list()

  #(
    collect_matches(
      tracking,
      first,
      fn(key) {
        let #(first, _) = key
        first
      },
    ),
    collect_matches(
      tracking,
      second,
      fn(key) {
        let #(_, second) = key
        second
      },
    ),
  )
}

fn collect_matches(tracking, str, extract_fun) {
  let matching_indexes =
    map.keys(tracking)
    |> list.map(extract_fun)
    |> set.from_list()

  let matches =
    str
    |> string.to_graphemes()
    |> list.index_map(fn(index, char) {
      case set.contains(matching_indexes, index) {
        True -> Match(char)
        False -> NoMatch(char)
      }
    })

  matches
  // |> list.reverse()
  |> list.chunk(fn(match) {
    case match {
      Match(_) -> True
      NoMatch(_) -> False
    }
  })
  |> list.map(fn(match_list) {
    case match_list {
      [Match(_), ..] ->
        Match(
          list.filter_map(
            match_list,
            fn(match) {
              case match {
                Match(char) -> Ok(char)
                NoMatch(char) -> Error(Nil)
              }
            },
          )
          |> string.join(""),
        )
      [NoMatch(_), ..] ->
        NoMatch(
          list.filter_map(
            match_list,
            fn(match) {
              case match {
                NoMatch(char) -> Ok(char)
                Match(char) -> Error(Nil)
              }
            },
          )
          |> string.join(""),
        )
    }
  })
}

fn back_track(
  diff_map: DiffMap,
  first_index: Int,
  second_index: Int,
  stack: List(MatchedChar),
) -> List(MatchedChar) {
  case first_index == 0 || second_index == 0 {
    True -> {
      let this_score =
        map.get(diff_map, #(first_index, second_index))
        |> result.unwrap(Score(0, None))
      case this_score {
        Score(_, Some(char)) -> [#(#(first_index, second_index), char), ..stack]
        _ -> stack
      }
    }
    False -> {
      let this_score =
        map.get(diff_map, #(first_index, second_index))
        |> result.unwrap(Score(0, None))
      case this_score {
        Score(_, Some(char)) ->
          back_track(
            diff_map,
            first_index - 1,
            second_index - 1,
            [#(#(first_index, second_index), char), ..stack],
          )
        Score(_, None) -> {
          let up =
            map.get(diff_map, #(first_index, second_index - 1))
            |> result.unwrap(Score(0, None))
          let back =
            map.get(diff_map, #(first_index - 1, second_index))
            |> result.unwrap(Score(0, None))
          case int.compare(up.value, back.value) {
            Gt -> back_track(diff_map, first_index, second_index - 1, stack)
            Lt -> back_track(diff_map, first_index - 1, second_index, stack)
            Eq ->
              case first_index, second_index {
                0, a if a > 0 ->
                  back_track(diff_map, first_index, second_index - 1, stack)
                a, 0 if a > 0 ->
                  back_track(diff_map, first_index - 1, second_index, stack)
                0, 0 -> stack
                _, _ ->
                  back_track(diff_map, first_index - 1, second_index, stack)
              }
          }
        }
      }
    }
  }
}

fn build_string_map(str: String) -> StringMap {
  str
  |> string.to_graphemes()
  |> list.index_map(fn(index, char) { #(index, char) })
  |> map.from_list()
}

fn build_diff_map(
  first_char,
  first_index,
  second_char,
  second_index,
  diff_map: DiffMap,
) -> DiffMap {
  let prev_score =
    map.get(diff_map, #(first_index - 1, second_index - 1))
    |> result.unwrap(Score(0, None))
  let derived_score_up =
    diff_map
    |> map.get(#(first_index, second_index - 1))
    |> result.unwrap(Score(0, None))
  let derived_score_back =
    diff_map
    |> map.get(#(first_index - 1, second_index))
    |> result.unwrap(Score(0, None))
  let derived_score = int.max(derived_score_up.value, derived_score_back.value)
  let this_score = case first_char == second_char {
    True -> Score(prev_score.value + 1, Some(first_char))
    False -> Score(derived_score, None)
  }
  diff_map
  |> map.insert(#(first_index, second_index), this_score)
}
