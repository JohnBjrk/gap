import gleam/string
import gleam/list
import gleam/pair
import gleam/map.{Map}
import gleam/result
import gleam/option.{None, Option, Some}
import gleam/int
import gleam/order.{Eq, Gt, Lt}
import gleam/set
import gap/comparison.{
  Comparison, ListComparison, Match, NoMatch, Segments, StringComparison,
}
import gap/styled_comparison.{StyledComparison}
import gap/styling.{
  first_highlight_default, from_comparison, highlight, no_highlight,
  second_highlight_default, to_styled_comparison,
}

type MatchedItem(a) =
  #(#(Int, Int), a)

type Score(a) {
  Score(value: Int, item: Option(a))
}

type DiffMap(a) =
  Map(#(Int, Int), Score(a))

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
pub fn compare_strings(first: String, second: String) -> Comparison(String) {
  let comparison =
    compare_lists(string.to_graphemes(first), string.to_graphemes(second))
  case comparison {
    ListComparison(first, second) -> StringComparison(first, second)
    StringComparison(first, second) -> StringComparison(first, second)
  }
}

/// Compare two lists and return a `ListComparison` which will be styled as list
/// when passed to `to_styled`
pub fn compare_lists(
  first_sequence: List(a),
  second_sequence: List(a),
) -> Comparison(a) {
  let matching_start =
    list.zip(first_sequence, second_sequence)
    |> list.take_while(fn(pair) { pair.0 == pair.1 })
    |> list.map(pair.first)
  let num_matching_start = list.length(matching_start)
  let matching_end =
    list.zip(list.reverse(first_sequence), list.reverse(second_sequence))
    |> list.take_while(fn(pair) { pair.0 == pair.1 })
    |> list.map(pair.first)
    |> list.reverse()
  let num_matching_end = list.length(matching_end)
  let first_sequence_to_diff =
    first_sequence
    |> list.drop(num_matching_start)
    |> list.take(
      list.length(first_sequence) - num_matching_start - num_matching_end,
    )
  let second_sequence_to_diff =
    second_sequence
    |> list.drop(num_matching_start)
    |> list.take(
      list.length(second_sequence) - num_matching_start - num_matching_end,
    )

  let diff_map =
    second_sequence_to_diff
    |> list.index_fold(
      map.new(),
      fn(diff_map, item_second, index_second) {
        first_sequence_to_diff
        |> list.index_fold(
          diff_map,
          fn(diff_map, item_first, index_first) {
            build_diff_map(
              item_first,
              index_first,
              item_second,
              index_second,
              diff_map,
            )
          },
        )
      },
    )
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
        |> map.from_list()

      let first_segments =
        collect_matches(
          tracking,
          first_sequence_to_diff,
          fn(key) {
            let #(first, _) = key
            first
          },
        )
      let second_segments =
        collect_matches(
          tracking,
          second_sequence_to_diff,
          fn(key) {
            let #(_, second) = key
            second
          },
        )
      #(first_segments, second_segments)
    }
  }

  let #(first_segments_with_start_end, second_segments_with_start_end) = case
    matching_start,
    matching_end
  {
    [], [] -> #(first_segments, second_segments)
    [], matching_end -> #(
      first_segments
      |> append_and_merge(Match(matching_end)),
      second_segments
      |> append_and_merge(Match(matching_end)),
    )
    matching_start, [] -> #(
      first_segments
      |> prepend_and_merge(Match(matching_start)),
      second_segments
      |> prepend_and_merge(Match(matching_start)),
    )
    matching_start, matching_end -> #(
      first_segments
      |> prepend_and_merge(Match(matching_start))
      |> append_and_merge(Match(matching_end)),
      second_segments
      |> prepend_and_merge(Match(matching_start))
      |> append_and_merge(Match(matching_end)),
    )
  }

  ListComparison(first_segments_with_start_end, second_segments_with_start_end)
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
    [Match(first_match), ..rest], Match(_) ->
      [
        Match(
          first_match
          |> list.append(match.item),
        ),
        ..rest
      ]
      |> list.reverse()
    [NoMatch(first_match), ..rest], NoMatch(_) ->
      [
        NoMatch(
          first_match
          |> list.append(match.item),
        ),
        ..rest
      ]
      |> list.reverse()
    matches, match ->
      [match, ..matches]
      |> list.reverse()
  }
}

fn collect_matches(tracking, str: List(a), extract_fun) -> Segments(a) {
  let matching_indexes =
    map.keys(tracking)
    |> list.map(extract_fun)
    |> set.from_list()

  let matches =
    str
    |> list.index_map(fn(index, item) {
      case set.contains(matching_indexes, index) {
        True -> Match(item)
        False -> NoMatch(item)
      }
    })

  matches
  |> list.chunk(fn(match) {
    case match {
      Match(_) -> True
      NoMatch(_) -> False
    }
  })
  |> list.map(fn(match_list) {
    case match_list {
      [Match(_), ..] ->
        Match(list.filter_map(
          match_list,
          fn(match) {
            case match {
              Match(item) -> Ok(item)
              NoMatch(_) -> Error(Nil)
            }
          },
        ))
      [NoMatch(_), ..] ->
        NoMatch(list.filter_map(
          match_list,
          fn(match) {
            case match {
              NoMatch(item) -> Ok(item)
              Match(_) -> Error(Nil)
            }
          },
        ))
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
        map.get(diff_map, #(first_index, second_index))
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
        map.get(diff_map, #(first_index, second_index))
        |> result.unwrap(Score(0, None))
      case this_score {
        Score(_, Some(item)) ->
          back_track(
            diff_map,
            first_index - 1,
            second_index - 1,
            [#(#(first_index, second_index), item), ..stack],
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

fn build_diff_map(
  first_item: a,
  first_index: Int,
  second_item: a,
  second_index: Int,
  diff_map: DiffMap(a),
) -> DiffMap(a) {
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
  let this_score = case first_item == second_item {
    True -> Score(prev_score.value + 1, Some(first_item))
    False -> Score(derived_score, None)
  }
  diff_map
  |> map.insert(#(first_index, second_index), this_score)
}
