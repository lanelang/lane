///|
pub(all) struct TypedCandidate {
  reference : @resolve.ResolvedValueReference
  type_ : @types.Type
} derive(Debug, Eq)

///|
pub(all) enum Selection {
  Selected(TypedCandidate)
  Ambiguous(name~ : String, candidates~ : Array[TypedCandidate])
  NoMatch(name~ : String)
} derive(Debug, Eq)

///|
pub(all) struct CallableCandidate {
  reference : @resolve.ResolvedValueReference
  type_arguments : Array[@types.Type]
  parameters : Array[@types.Type]
  result : @types.Type
} derive(Debug, Eq)

///|
pub(all) enum CallableSelection {
  Selected(CallableCandidate)
  Ambiguous(name~ : String, candidates~ : Array[CallableCandidate])
  NoMatch(name~ : String)
} derive(Debug, Eq)

///|
/// Selects a candidate only when the candidate set is already unique.
pub fn select_without_context(
  name : String,
  candidates : Array[TypedCandidate],
) -> Selection {
  select_from(name, candidates, fn(_) { true })
}

///|
/// Selects the unique candidate whose type equals the expected type.
pub fn select_by_expected(
  name : String,
  candidates : Array[TypedCandidate],
  expected : @types.Type,
) -> Selection {
  select_from(name, candidates, fn(candidate) {
    candidate.type_.equals(expected)
  })
}

///|
fn select_from(
  name : String,
  candidates : Array[TypedCandidate],
  keep : (TypedCandidate) -> Bool,
) -> Selection {
  let matches = []
  for candidate in candidates {
    if keep(candidate) {
      matches.push(candidate)
    }
  }
  match matches.length() {
    0 => NoMatch(name~)
    1 => Selected(matches[0])
    _ => Ambiguous(name~, candidates=matches)
  }
}
