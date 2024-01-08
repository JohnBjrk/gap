import gleam/list

pub type Edit(a) {
  Eq(List(a))
  Del(List(a))
  Ins(List(a))
}

type Path(a) {
  Path(x: Int, y: Int, list1: List(a), list2: List(a), edits: List(Edit(a)))
}

type Status(a) {
  Done(edits: List(Edit(a)))
  Next(paths: List(Path(a)))
  Cont(path: Path(a))
}

/// The algorithm is outlined in the
/// "An O(ND) Difference Algorithm and Its Variations" paper by E. Myers.
/// 
/// Adapted from the implementation of "myers_difference" in Elixirs List module
pub fn difference(list1: List(a), list2: List(a)) -> List(Edit(a)) {
  let path = Path(0, 0, list1, list2, [])
  find_script(0, list.length(list1) + list.length(list2), [path])
}

fn find_script(envelope: Int, max: Int, paths: List(Path(a))) {
  case envelope > max {
    True -> []
    False -> {
      case each_diagonal(-envelope, envelope, paths, []) {
        Done(edits) -> compact_reverse(edits, [])
        Next(paths) -> find_script(envelope + 1, max, paths)
        _ -> panic as "Didn't expect a Cont here"
      }
    }
  }
}

fn compact_reverse(edits: List(Edit(a)), acc: List(Edit(a))) -> List(Edit(a)) {
  case edits, acc {
    [], acc -> acc
    [Eq(elem), ..rest], [Eq(result), ..acc_rest] ->
      compact_reverse(rest, [Eq(list.flatten([elem, result])), ..acc_rest])
    [Del(elem), ..rest], [Del(result), ..acc_rest] ->
      compact_reverse(rest, [Del(list.flatten([elem, result])), ..acc_rest])
    [Ins(elem), ..rest], [Ins(result), ..acc_rest] ->
      compact_reverse(rest, [Ins(list.flatten([elem, result])), ..acc_rest])
    [Eq(elem), ..rest], acc -> compact_reverse(rest, [Eq(elem), ..acc])
    [Del(elem), ..rest], acc -> compact_reverse(rest, [Del(elem), ..acc])
    [Ins(elem), ..rest], acc -> compact_reverse(rest, [Ins(elem), ..acc])
  }
}

fn each_diagonal(
  diag: Int,
  limit: Int,
  paths: List(Path(a)),
  next_paths: List(Path(a)),
) -> Status(a) {
  case diag > limit {
    True -> Next(list.reverse(next_paths))
    False -> {
      let #(path, rest) = proceed_path(diag, limit, paths)
      case follow_snake(path) {
        Cont(path) -> each_diagonal(diag + 2, limit, rest, [path, ..next_paths])
        other -> other
      }
    }
  }
}

fn proceed_path(
  diag: Int,
  limit: Int,
  paths: List(Path(a)),
) -> #(Path(a), List(Path(a))) {
  let neg_limit = -limit
  case diag, limit, paths {
    0, 0, [path] -> #(path, [])
    diag, _limit, [path, ..] as paths if diag == neg_limit -> #(
      move_down(path),
      paths,
    )
    diag, limit, [path, ..] as paths if diag == limit -> #(
      move_right(path),
      paths,
    )
    _diag, _limit, [path1, path2, ..rest] -> {
      case path1.y > path2.y {
        True -> #(move_right(path1), [path2, ..rest])
        False -> #(move_down(path2), [path2, ..rest])
      }
    }
    _, _, _ -> panic as "Unexpected case"
  }
}

fn move_right(path: Path(a)) -> Path(a) {
  case path {
    Path(x, y, list1, [elem, ..rest], edits) ->
      Path(x + 1, y, list1, rest, [Ins([elem]), ..edits])
    Path(x, y, list1, [], edits) -> Path(x + 1, y, list1, [], edits)
  }
}

fn move_down(path: Path(a)) -> Path(a) {
  case path {
    Path(x, y, [elem, ..rest], list2, edits) ->
      Path(x, y + 1, rest, list2, [Del([elem]), ..edits])
    Path(x, y, [], list2, edits) -> Path(x, y + 1, [], list2, edits)
  }
}

fn follow_snake(path: Path(a)) -> Status(a) {
  case path {
    Path(x, y, [elem1, ..rest1], [elem2, ..rest2], edits) if elem1 == elem2 ->
      follow_snake(Path(x + 1, y + 1, rest1, rest2, [Eq([elem1]), ..edits]))
    Path(_x, _y, [], [], edits) -> Done(edits)
    _ -> Cont(path)
  }
}
