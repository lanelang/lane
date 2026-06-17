///|
fn SemanticChecker::check_candidate_reference(
  self : SemanticChecker,
  scope : TypeScope,
  name : String,
  candidates : Array[@resolve.ResolvedValueReference],
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  // Gamma |- c_i : T_i
  // T_i = Expected
  // ---
  // Gamma |- x <= Expected
  //
  // Open exposure can make `x` a candidate set. Checking mode uses the expected
  // type to select the unique candidate; ambiguity remains visible to users.
  let typed_candidates = self.typed_candidates(scope, candidates, name, loc)
  match @candidates.select_by_expected(name, typed_candidates, expected) {
    Selected(_) => ()
    Ambiguous(name~, ..) => self.report_ambiguous_value_reference(name, loc)
    NoMatch(name~) =>
      self.diagnostics.push({
        kind: CannotInferExpression("no matching value reference " + name),
        loc,
      })
  }
}

///|
fn SemanticChecker::synthesize_value_reference(
  self : SemanticChecker,
  scope : TypeScope,
  reference : @resolve.ResolvedValueReference,
  name : String,
  loc : SourceSpan,
) -> @types.Type {
  match reference {
    Symbol(symbol) =>
      match scope.lookup(symbol) {
        Some(type_) => type_
        None => {
          self.diagnostics.push({ kind: UnresolvedValue(name), loc })
          Error
        }
      }
    OpenedField(base~, path~) =>
      match scope.lookup(base) {
        Some(base_type) =>
          self.declarations.field_path_type(
            self.diagnostics,
            base_type,
            path,
            name,
            loc,
          )
        None => {
          self.diagnostics.push({ kind: UnresolvedValue(name), loc })
          Error
        }
      }
    Candidates(name~, candidates~) => {
      let typed_candidates = self.typed_candidates(scope, candidates, name, loc)
      match @candidates.select_without_context(name, typed_candidates) {
        Selected(candidate) => candidate.type_
        Ambiguous(name~, ..) => {
          self.report_ambiguous_value_reference(name, loc)
          Error
        }
        NoMatch(name~) => {
          self.diagnostics.push({
            kind: CannotInferExpression("no matching value reference " + name),
            loc,
          })
          Error
        }
      }
    }
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      Error
    }
  }
}

///|
fn SemanticChecker::typed_candidates(
  self : SemanticChecker,
  scope : TypeScope,
  candidates : Array[@resolve.ResolvedValueReference],
  name : String,
  loc : SourceSpan,
) -> Array[@candidates.TypedCandidate] {
  let typed = []
  for candidate in candidates {
    if self.typed_candidate(scope, candidate, name, loc) is Some(candidate) {
      typed.push(candidate)
    }
  }
  typed
}

///|
fn SemanticChecker::typed_candidate(
  self : SemanticChecker,
  scope : TypeScope,
  reference : @resolve.ResolvedValueReference,
  name : String,
  loc : SourceSpan,
) -> @candidates.TypedCandidate? {
  match reference {
    Symbol(symbol) =>
      match scope.lookup(symbol) {
        Some(type_) => Some({ reference, type_ })
        None => {
          self.diagnostics.push({ kind: UnresolvedValue(name), loc })
          None
        }
      }
    OpenedField(base~, path~) =>
      match scope.lookup(base) {
        Some(base_type) =>
          Some({
            reference,
            type_: self.declarations.field_path_type(
              self.diagnostics,
              base_type,
              path,
              name,
              loc,
            ),
          })
        None => {
          self.diagnostics.push({ kind: UnresolvedValue(name), loc })
          None
        }
      }
    Candidates(..) => None
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      None
    }
  }
}
