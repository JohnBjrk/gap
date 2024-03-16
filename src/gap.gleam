import gleam/string
import gleam/list
import gleam/pair
import gleam/dict.{type Dict}
import gleam/result
import gleam/option.{type Option, None, Some}
import gleam/int
import gleam/order.{Eq, Gt, Lt}
import gleam/set
import gap/comparison.{
  type Comparison, type Match, type Segments, ListComparison, Match, NoMatch,
  StringComparison,
}
import gap/styled_comparison.{type StyledComparison}
import gap/styling.{
  first_highlight_default, from_comparison, highlight, no_highlight,
  second_highlight_default, to_styled_comparison,
}
import gap/myers.{type Edit, Del, Eq as MyerEq, Ins}

type MatchedItem(a) =
  #(#(Int, Int), a)

type Score(a) {
  Score(value: Int, item: Option(a))
}

type DiffMap(a) =
  Dict(#(Int, Int), Score(a))

/// Creates a `StyledComparison` from `Comparison` using default values for
/// highting and serialization.
///
/// ## Example
///
/// ```gleam
/// > compare_strings("abc", "abe") |> to_styled()
/// ```
/// This will return a `StyledComparison(first, second)` where "c" in `first` is green
/// and "e" in `second` is red.
pub fn to_styled(comparison: Comparison(a)) -> StyledComparison {
  comparison
  |> from_comparison()
  |> highlight(first_highlight_default, second_highlight_default, no_highlight)
  |> to_styled_comparison()
}

/// Compare two string and return a `StringComparison` which will be styled as string
/// when passed to `to_styled`
/// 
/// Will use the default `myers` algorithm
pub fn compare_strings(first: String, second: String) -> Comparison(String) {
  let comparison =
    compare_lists(string.to_graphemes(first), string.to_graphemes(second))
  case comparison {
    ListComparison(first, second) -> StringComparison(first, second)
    StringComparison(first, second) -> StringComparison(first, second)
  }
}

/// Compare two string and return a `StringComparison` which will be styled as string
/// when passed to `to_styled`
/// 
/// Algorithm can be used to select either `myers` or the legacy `lcs` algorithm
pub fn compare_strings_with_algorithm(
  first: String,
  second: String,
  algorithm,
) -> Comparison(String) {
  let comparison =
    algorithm(string.to_graphemes(first), string.to_graphemes(second))
  case comparison {
    ListComparison(first, second) -> StringComparison(first, second)
    StringComparison(first, second) -> StringComparison(first, second)
  }
}

/// Compare two lists and return a `ListComparison` which will be styled as list
/// when passed to `to_styled`
/// 
/// Will use the default `myers` algorithm
pub fn compare_lists(
  first_sequence: List(a),
  second_sequence: List(a),
) -> Comparison(a) {
  myers(first_sequence, second_sequence)
}

/// Compare two lists and return a `ListComparison` which will be styled as list
/// when passed to `to_styled`
/// 
/// Algorithm can be used to select either `myers` or the legacy `lcs` algorithm
pub fn compare_lists_with_algorithm(
  first_sequence: List(a),
  second_sequence: List(a),
  algorithm,
) -> Comparison(a) {
  algorithm(first_sequence, second_sequence)
}

/// An adapter for the the `myers` algorithm.
/// Intended to be use as an argument to `compare_strings_with_algorithm` or
/// `compare_lists_with_algorithm`
pub fn myers(first_sequence: List(a), second_sequence: List(a)) -> Comparison(a) {
  let edits = myers.difference(first_sequence, second_sequence)
  edits
  |> list.reverse()
  |> list.fold(
    ListComparison([], []),
    fn(comparison: Comparison(a), edit: Edit(a)) {
      case comparison {
        ListComparison(first, second) -> {
          case edit {
            MyerEq(segment) ->
              ListComparison([Match(segment), ..first], [
                Match(segment),
                ..second
              ])
            Ins(segment) -> ListComparison(first, [NoMatch(segment), ..second])
            Del(segment) -> ListComparison([NoMatch(segment), ..first], second)
          }
        }
        StringComparison(..) -> comparison
      }
    },
  )
}

/// An adapter for the the `lcs` (longest common subsequence) algorithm.
/// Intended to be use as an argument to `compare_strings_with_algorithm` or
/// `compare_lists_with_algorithm`
pub fn lcs(first_sequence: List(a), second_sequence: List(a)) -> Comparison(a) {
  let leading_matches =
    list.zip(first_sequence, second_sequence)
    |> list.take_while(fn(pair) { pair.0 == pair.1 })
    |> list.map(pair.first)
  let num_leading_matches = list.length(leading_matches)
  let trailing_matches =
    list.zip(list.reverse(first_sequence), list.reverse(second_sequence))
    |> list.take_while(fn(pair) { pair.0 == pair.1 })
    |> list.map(pair.first)
    |> list.reverse()
  let num_trailing_matches = list.length(trailing_matches)
  let first_sequence_to_diff =
    first_sequence
    |> list.drop(num_leading_matches)
    |> list.take(
      list.length(first_sequence) - num_leading_matches - num_trailing_matches,
    )
  let second_sequence_to_diff =
    second_sequence
    |> list.drop(num_leading_matches)
    |> list.take(
      list.length(second_sequence) - num_leading_matches - num_trailing_matches,
    )

  let diff_map =
    second_sequence_to_diff
    |> list.index_fold(dict.new(), fn(diff_map, item_second, index_second) {
      first_sequence_to_diff
      |> list.index_fold(diff_map, fn(diff_map, item_first, index_first) {
        build_diff_map(
          item_first,
          index_first,
          item_second,
          index_second,
          diff_map,
        )
      })
    })
  let #(first_segments, second_segments) = case
    first_sequence_to_diff,
    second_sequence_to_diff
  {
    [], [] -> #([], [])
    first_matching, [] -> #([NoMatch(first_matching)], [])
    [], second_matching -> #([], [NoMatch(second_matching)])
    first_sequence_to_diff, second_sequence_to_diff -> {
      let tracking =
        back_track(
          diff_map,
          list.length(first_sequence_to_diff) - 1,
          list.length(second_sequence_to_diff) - 1,
          [],
        )
        |> dict.from_list()

      let first_segments =
        collect_matches(tracking, first_sequence_to_diff, fn(key) {
          let #(first, _) = key
          first
        })
      let second_segments =
        collect_matches(tracking, second_sequence_to_diff, fn(key) {
          let #(_, second) = key
          second
        })
      #(first_segments, second_segments)
    }
  }

  let #(
    first_segments_with_leading_trailing,
    second_segments_with_leading_trailing,
  ) = case leading_matches, trailing_matches {
    [], [] -> #(first_segments, second_segments)
    [], trailing_matches -> #(
      first_segments
        |> append_and_merge(Match(trailing_matches)),
      second_segments
        |> append_and_merge(Match(trailing_matches)),
    )
    leading_matches, [] -> #(
      first_segments
        |> prepend_and_merge(Match(leading_matches)),
      second_segments
        |> prepend_and_merge(Match(leading_matches)),
    )
    leading_matches, trailing_matches -> #(
      first_segments
        |> prepend_and_merge(Match(leading_matches))
        |> append_and_merge(Match(trailing_matches)),
      second_segments
        |> prepend_and_merge(Match(leading_matches))
        |> append_and_merge(Match(trailing_matches)),
    )
  }

  ListComparison(
    first_segments_with_leading_trailing,
    second_segments_with_leading_trailing,
  )
}

fn prepend_and_merge(
  matches: List(Match(List(a))),
  match: Match(List(a)),
) -> List(Match(List(a))) {
  case matches, match {
    [], _ -> [match]
    [Match(first_match), ..rest], Match(_) -> [
      Match(
        match.item
        |> list.append(first_match),
      ),
      ..rest
    ]
    [NoMatch(first_match), ..rest], NoMatch(_) -> [
      NoMatch(
        match.item
        |> list.append(first_match),
      ),
      ..rest
    ]
    matches, match -> [match, ..matches]
  }
}

fn append_and_merge(
  matches: List(Match(List(a))),
  match: Match(List(a)),
) -> List(Match(List(a))) {
  case
    matches
    |> list.reverse(),
    match
  {
    [], _ -> [match]
    [Match(first_match), ..rest], Match(_) -> [
      Match(
        first_match
        |> list.append(match.item),
      ),
      ..rest
    ]
    [NoMatch(first_match), ..rest], NoMatch(_) -> [
      NoMatch(
        first_match
        |> list.append(match.item),
      ),
      ..rest
    ]
    matches, match -> [match, ..matches]
  }
  |> list.reverse()
}

fn collect_matches(
  tracking: Dict(#(Int, Int), b),
  str: List(a),
  extract_fun: fn(#(Int, Int)) -> Int,
) -> Segments(a) {
  let matching_indexes: set.Set(Int) =
    dict.keys(tracking)
    |> list.map(extract_fun)
    |> set.from_list()

  let matches: List(Match(a)) =
    str
    |> list.index_map(fn(item: a, index: Int) {
      case set.contains(matching_indexes, index) {
        True -> Match(item)
        False -> NoMatch(item)
      }
    })

  matches
  |> list.chunk(fn(match: Match(a)) {
    case match {
      Match(_) -> True
      NoMatch(_) -> False
    }
  })
  |> list.map(fn(match_list) {
    case match_list {
      [] -> Match([])
      [Match(_), ..] ->
        Match(
          list.filter_map(match_list, fn(match) {
            case match {
              Match(item) -> Ok(item)
              NoMatch(_) -> Error(Nil)
            }
          }),
        )
      [NoMatch(_), ..] ->
        NoMatch(
          list.filter_map(match_list, fn(match) {
            case match {
              NoMatch(item) -> Ok(item)
              Match(_) -> Error(Nil)
            }
          }),
        )
    }
  })
}

fn back_track(
  diff_map: DiffMap(a),
  first_index: Int,
  second_index: Int,
  stack: List(MatchedItem(a)),
) -> List(MatchedItem(a)) {
  case first_index == 0 || second_index == 0 {
    True -> {
      let this_score =
        dict.get(diff_map, #(first_index, second_index))
        |> result.unwrap(Score(0, None))
      case this_score {
        Score(_, Some(item)) -> [#(#(first_index, second_index), item), ..stack]
        _ ->
          case first_index, second_index {
            0, a if a > 0 ->
              back_track(diff_map, first_index, second_index - 1, stack)
            a, 0 if a > 0 ->
              back_track(diff_map, first_index - 1, second_index, stack)
            0, 0 -> stack
            _, _ -> back_track(diff_map, first_index - 1, second_index, stack)
          }
      }
    }
    False -> {
      let this_score =
        dict.get(diff_map, #(first_index, second_index))
        |> result.unwrap(Score(0, None))
      case this_score {
        Score(_, Some(item)) ->
          back_track(diff_map, first_index - 1, second_index - 1, [
            #(#(first_index, second_index), item),
            ..stack
          ])
        Score(_, None) -> {
          let up =
            dict.get(diff_map, #(first_index, second_index - 1))
            |> result.unwrap(Score(0, None))
          let back =
            dict.get(diff_map, #(first_index - 1, second_index))
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

fn build_diff_map(
  first_item: a,
  first_index: Int,
  second_item: a,
  second_index: Int,
  diff_map: DiffMap(a),
) -> DiffMap(a) {
  let prev_score =
    dict.get(diff_map, #(first_index - 1, second_index - 1))
    |> result.unwrap(Score(0, None))
  let derived_score_up =
    diff_map
    |> dict.get(#(first_index, second_index - 1))
    |> result.unwrap(Score(0, None))
  let derived_score_back =
    diff_map
    |> dict.get(#(first_index - 1, second_index))
    |> result.unwrap(Score(0, None))
  let derived_score = int.max(derived_score_up.value, derived_score_back.value)
  let this_score = case first_item == second_item {
    True -> Score(prev_score.value + 1, Some(first_item))
    False -> Score(derived_score, None)
  }
  diff_map
  |> dict.insert(#(first_index, second_index), this_score)
}
