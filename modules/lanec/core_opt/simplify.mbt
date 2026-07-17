///|
priv struct ValueSubstitution {
  value : @buslane.ValueId
  replacement : @buslane.Expr
}

///|
fn simplify_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> @buslane.Program {
  let preserved_roots = roots.copy()
  preserved_roots.push(entry)
  let mut current = program
  for _ in 0..<4 {
    let analysis = analyze_core(current, entry, roots)
    let next = simplify_program_once(current, analysis, preserved_roots)
    if next.terms == current.terms {
      return next
    }
    current = next
  }
  current
}

///|
fn simplify_program_once(
  program : @buslane.Program,
  analysis : CoreAnalysis,
  preserved_roots : Array[@buslane.ValueId],
) -> @buslane.Program {
  let substitutions = collect_top_aliases(program, preserved_roots)
  let terms = []
  for term in program.terms {
    match term {
      Let(value, _) if substitutions.has_substitution(value) => ()
      Let(value, rhs) =>
        terms.push(
          @buslane.TopTerm::Let(
            value,
            simplify_expr(program, analysis, substitutions, rhs),
          ),
        )
      LetRec(bindings) =>
        terms.push(
          LetRec(
            bindings.map(binding => {
              ..binding,
              rhs: simplify_expr(program, analysis, substitutions, binding.rhs),
            }),
          ),
        )
      External(value) => terms.push(External(value))
    }
  }
  { ..program, terms, }
}

///|
fn collect_top_aliases(
  program : @buslane.Program,
  preserved_roots : Array[@buslane.ValueId],
) -> Array[ValueSubstitution] {
  let substitutions = []
  for term in program.terms {
    guard term is Let(value, Ref(target)) else { continue }
    if !preserved_roots.contains(value) &&
      compatible_alias(program, value, target) {
      substitutions.push({ value, replacement: Ref(target) })
    }
  }
  substitutions
}

///|
fn compatible_alias(
  program : @buslane.Program,
  value : @buslane.ValueId,
  target : @buslane.ValueId,
) -> Bool {
  guard program.metadata.value_info(value) is Some(value_info) else {
    return false
  }
  guard program.metadata.value_info(target) is Some(target_info) else {
    return false
  }
  value_info.type_.equals(target_info.type_)
}

///|
fn simplify_expr(
  program : @buslane.Program,
  analysis : CoreAnalysis,
  substitutions : Array[ValueSubstitution],
  expression : @buslane.Expr,
) -> @buslane.Expr {
  match expression {
    Ref(value) => substitutions.resolve_ref(value)
    Literal(_) => expression
    Function(function) =>
      Function({
        ..function,
        body: simplify_expr(program, analysis, substitutions, function.body),
      })
    Call(callee, arguments) => {
      let callee = simplify_expr(program, analysis, substitutions, callee)
      let arguments = arguments.map(argument => {
        simplify_expr(program, analysis, substitutions, argument)
      })
      simplify_call(program, analysis, substitutions, callee, arguments)
    }
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters,
        simplify_expr(program, analysis, substitutions, body),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        simplify_expr(program, analysis, substitutions, callee),
        arguments,
      )
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          simplify_expr(program, analysis, substitutions, payload)
        }),
      })
    Let(value, initializer, body) => {
      let initializer = simplify_expr(
        program, analysis, substitutions, initializer,
      )
      let can_substitute = match initializer {
        Ref(target) => compatible_alias(program, value, target)
        Literal(_) => true
        _ => false
      }
      if can_substitute {
        let nested = substitutions.copy()
        nested.push({ value, replacement: initializer })
        simplify_expr(program, analysis, nested, body)
      } else {
        let body = simplify_expr(program, analysis, substitutions, body)
        if count_value_uses(body, value) == 0 &&
          expression_is_pure(program, initializer) {
          body
        } else {
          Let(value, initializer, body)
        }
      }
    }
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: simplify_expr(program, analysis, substitutions, binding.rhs),
        }),
        simplify_expr(program, analysis, substitutions, body),
      )
    Match(match_) => {
      let scrutinee = simplify_expr(
        program,
        analysis,
        substitutions,
        match_.scrutinee,
      )
      let alternatives = match_.alternatives.map(alternative => {
        ..alternative,
        body: simplify_expr(program, analysis, substitutions, alternative.body),
      })
      let rewritten = @buslane.Expr::Match({ ..match_, scrutinee, alternatives })
      match known_match_reduction(program, analysis, rewritten) {
        Some(reduced) =>
          simplify_expr(program, analysis, substitutions, reduced)
        None => rewritten
      }
    }
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => {
          simplify_expr(program, analysis, substitutions, payload)
        }),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: simplify_expr(program, analysis, substitutions, handle.body),
        final_body: simplify_expr(
          program,
          analysis,
          substitutions,
          handle.final_body,
        ),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: simplify_expr(
              program,
              analysis,
              substitutions,
              operation.body,
            ),
          }),
        }),
      })
    Resume(value) => substitutions.resolve_resume(value)
  }
}

///|
fn simplify_call(
  program : @buslane.Program,
  analysis : CoreAnalysis,
  substitutions : Array[ValueSubstitution],
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr {
  if try_specialize_generic_call(program, analysis, callee, arguments)
    is Some(specialized) {
    return simplify_expr(program, analysis, substitutions, specialized)
  }
  guard callee is Function(function) &&
    function.parameters.length() == arguments.length() &&
    arguments.all(is_substitutable_atom) else {
    return Call(callee, arguments)
  }
  let nested = substitutions.copy()
  for index in 0..<arguments.length() {
    nested.push({
      value: function.parameters[index],
      replacement: arguments[index],
    })
  }
  simplify_expr(program, analysis, nested, function.body)
}

///|
fn is_substitutable_atom(expression : @buslane.Expr) -> Bool {
  expression is Ref(_) || expression is Literal(_)
}

///|
fn Array::has_substitution(
  self : Array[ValueSubstitution],
  value : @buslane.ValueId,
) -> Bool {
  self.any(substitution => substitution.value == value)
}

///|
fn Array::resolve_ref(
  self : Array[ValueSubstitution],
  value : @buslane.ValueId,
) -> @buslane.Expr {
  self.resolve_ref_with_fuel(value, self.length() + 1)
}

///|
fn Array::resolve_ref_with_fuel(
  self : Array[ValueSubstitution],
  value : @buslane.ValueId,
  fuel : Int,
) -> @buslane.Expr {
  if fuel == 0 {
    return Ref(value)
  }
  guard self.find_replacement(value) is Some(replacement) else {
    return Ref(value)
  }
  match replacement {
    Ref(target) if target != value =>
      self.resolve_ref_with_fuel(target, fuel - 1)
    _ => replacement
  }
}

///|
fn Array::resolve_resume(
  self : Array[ValueSubstitution],
  value : @buslane.ValueId,
) -> @buslane.Expr {
  match self.resolve_ref(value) {
    Ref(target) => Resume(target)
    _ => Resume(value)
  }
}

///|
fn Array::find_replacement(
  self : Array[ValueSubstitution],
  value : @buslane.ValueId,
) -> @buslane.Expr? {
  for substitution in self.rev_iter() {
    if substitution.value == value {
      return Some(substitution.replacement)
    }
  }
  None
}

///|
fn known_match_reduction(
  program : @buslane.Program,
  analysis : CoreAnalysis,
  expression : @buslane.Expr,
) -> @buslane.Expr? {
  guard expression is Match(match_) else { return None }
  match match_.scrutinee {
    Construct(construct) => reduce_constructor_match(match_, construct)
    Ref(value) =>
      match analysis.find_top_definition(value) {
        Some(Construct(construct)) if match_.alternatives.all(alternative => {
            count_value_uses(alternative.body, match_.binder) == 0
          }) &&
          construct.payloads.all(payload => expression_is_pure(program, payload)) =>
          reduce_static_constructor_projection(match_, construct)
        _ => None
      }
    Literal(literal) => reduce_literal_match(match_, literal)
    _ => None
  }
}

///|
fn reduce_static_constructor_projection(
  match_ : @buslane.MatchExpr,
  construct : @buslane.ConstructExpr,
) -> @buslane.Expr? {
  let selected = find_alternative(
    match_.alternatives,
    DataCon(construct.data_constructor),
  )
  guard selected is Some(alternative) &&
    alternative.type_binders.is_empty() &&
    alternative.value_binders.length() == construct.payloads.length() else {
    return None
  }
  let mut body = alternative.body
  let mut index = construct.payloads.length()
  while index > 0 {
    index = index - 1
    body = Let(
      alternative.value_binders[index],
      construct.payloads[index],
      body,
    )
  }
  Some(body)
}

///|
fn reduce_constructor_match(
  match_ : @buslane.MatchExpr,
  construct : @buslane.ConstructExpr,
) -> @buslane.Expr? {
  let selected = find_alternative(
    match_.alternatives,
    DataCon(construct.data_constructor),
  )
  guard selected is Some(alternative) && alternative.type_binders.is_empty() else {
    return None
  }
  if alternative.alt_constructor is DataCon(_) {
    guard alternative.value_binders.length() == construct.payloads.length() else {
      return None
    }
    let payload_refs = alternative.value_binders.map(value => {
      @buslane.Expr::Ref(value)
    })
    let mut body = @buslane.Expr::Let(
      match_.binder,
      Construct({ ..construct, payloads: payload_refs }),
      alternative.body,
    )
    let mut index = construct.payloads.length()
    while index > 0 {
      index = index - 1
      body = Let(
        alternative.value_binders[index],
        construct.payloads[index],
        body,
      )
    }
    Some(body)
  } else {
    Some(Let(match_.binder, Construct(construct), alternative.body))
  }
}

///|
fn reduce_literal_match(
  match_ : @buslane.MatchExpr,
  literal : @buslane.Literal,
) -> @buslane.Expr? {
  let selected = find_alternative(match_.alternatives, Literal(literal))
  guard selected is Some(alternative) &&
    alternative.type_binders.is_empty() &&
    alternative.value_binders.is_empty() else {
    return None
  }
  Some(Let(match_.binder, Literal(literal), alternative.body))
}

///|
fn find_alternative(
  alternatives : Array[@buslane.Alternative],
  alternative_constructor : @buslane.AltCon,
) -> @buslane.Alternative? {
  for alternative in alternatives {
    if alternative.alt_constructor == alternative_constructor {
      return Some(alternative)
    }
  }
  for alternative in alternatives {
    if alternative.alt_constructor is Default {
      return Some(alternative)
    }
  }
  None
}
