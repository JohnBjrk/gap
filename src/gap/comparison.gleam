/// Comparison of two strings or lists
///
/// The comparison consists of two lists of matched segments. The segments represent
/// a sequence of succeeding matches or non-matches (up until the next match/non-match)
/// 
/// For lists the elements in the segment will be same as the elements in the list, and
/// for strings the elements will be the graphemes of the string
pub type Comparison(a) {
  ListComparison(first: Segments(a), second: Segments(a))
  StringComparison(first: Segments(String), second: Segments(String))
}

/// Indicating that the item has a matching (`Match`) or no matching (`NoMatch`) item in the
/// other string/list
pub type Match(a) {
  Match(item: a)
  NoMatch(item: a)
}

/// List of segments of succeeding matches / non-matches
pub type Segments(a) =
  List(Match(List(a)))
