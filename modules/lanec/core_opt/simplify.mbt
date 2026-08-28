///|
priv struct ValueSubstitution {
  value : @buslane.ValueId
  replacement : @buslane.Expr
}

///|
priv struct CoreSimplifier {
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
  function_origins : @function_origin.FunctionOriginCatalog?
  observe : (CoreOptimizationObservation) -> Unit
}

///|
fn simplify_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  CoreSimplifier::{ entry, roots, function_origins, observe, }.run(program)
}

///|
fn CoreSimplifier::run(
  self : CoreSimplifier,
  program : @buslane.Program,
) -> @buslane.Program raise CoreOptimizeError {
  let preserved_roots = self.roots.copy()
  preserved_roots.push(self.entry)
  for current = program {
    let analysis = analyze_core(current)
    let next = simplify_program_once(
      current,
      analysis,
      preserved_roots,
      self.function_origins,
      self.observe,
    )
    if next.terms == current.terms {
      return next
    }
    continue next
  }
}

///|
priv struct CoreCleanup {
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
  function_origins : @function_origin.FunctionOriginCatalog?
  observe : (CoreOptimizationObservation) -> Unit
}

///|
/// Runs the local, effect-aware simplifier and removes unreachable terms.
/// This is the only cleanup boundary used before and after interprocedural
/// inlining.
fn cleanup_core(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  CoreCleanup::{ entry, roots, function_origins, observe, }.run(program)
}

///|
fn CoreCleanup::run(
  self : CoreCleanup,
  program : @buslane.Program,
) -> @buslane.Program raise CoreOptimizeError {
  for current = program {
    let simplified = simplify_program(
      current,
      self.entry,
      self.roots,
      self.function_origins,
      self.observe,
    )
    let commoned = eliminate_local_common_subexpressions(
      simplified,
      self.function_origins,
    )
    if commoned.terms == current.terms {
      break prune_unreachable(commoned, self.entry, self.roots)
    }
    continue commoned
  }
}

///|
priv struct CommonLocalInitializer {
  value : @buslane.ValueId
  initializer : @buslane.Expr
}

///|
/// Shares definitionally identical pure initializers only within one local
/// evaluation region. Top-level initializers remain distinct because their
/// ownership lifetime belongs to initializer orchestration.
fn eliminate_local_common_subexpressions(
  program : @buslane.Program,
  function_origins : @function_origin.FunctionOriginCatalog?,
) -> @buslane.Program raise CoreOptimizeError {
  let facts = @buslane.ExpressionFactsQuery::new(program)
  let terms = program.terms.map(term => {
    match term {
      Let(value, expression) =>
        @buslane.TopTerm::Let(
          value,
          eliminate_local_common_expr(
            program,
            facts,
            [],
            expression,
            function_origins,
          ),
        )
      LetRec(bindings) =>
        LetRec(
          bindings.map(binding => {
            ..binding,
            rhs: eliminate_local_common_expr(
              program,
              facts,
              [],
              binding.rhs,
              function_origins,
            ),
          }),
        )
      External(_) => term
    }
  })
  { ..program, terms, }
}

///|
fn eliminate_local_common_expr(
  program : @buslane.Program,
  facts : @buslane.ExpressionFactsQuery,
  available : Array[CommonLocalInitializer],
  expression : @buslane.Expr,
  function_origins : @function_origin.FunctionOriginCatalog?,
) -> @buslane.Expr raise CoreOptimizeError {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) => {
      let rewritten : @buslane.FunctionExpr = {
        ..function,
        body: eliminate_local_common_expr(
          program,
          facts,
          [],
          function.body,
          function_origins,
        ),
      }
      transfer_function_origin(function_origins, function, rewritten)
      Function(rewritten)
    }
    Call(callee, arguments) =>
      Call(
        eliminate_local_common_expr(
          program, facts, available, callee, function_origins,
        ),
        arguments.map(argument => {
          eliminate_local_common_expr(
            program, facts, available, argument, function_origins,
          )
        }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters,
        eliminate_local_common_expr(program, facts, [], body, function_origins),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        eliminate_local_common_expr(
          program, facts, available, callee, function_origins,
        ),
        arguments,
      )
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          eliminate_local_common_expr(
            program, facts, available, payload, function_origins,
          )
        }),
      })
    Let(value, initializer, body) => {
      let rewritten_initializer = eliminate_local_common_expr(
        program, facts, available, initializer, function_origins,
      )
      let is_pure = expression_has_empty_effect(facts, initializer)
      if is_pure {
        for common in available {
          if common.initializer == rewritten_initializer &&
            compatible_alias(program, value, common.value) {
            return Let(
              value,
              Ref(common.value),
              eliminate_local_common_expr(
                program, facts, available, body, function_origins,
              ),
            )
          }
        }
      }
      let body_available = available.copy()
      if is_pure {
        body_available.push({ value, initializer: rewritten_initializer, })
      }
      Let(
        value,
        rewritten_initializer,
        eliminate_local_common_expr(
          program, facts, body_available, body, function_origins,
        ),
      )
    }
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: eliminate_local_common_expr(
            program,
            facts,
            available,
            binding.rhs,
            function_origins,
          ),
        }),
        eliminate_local_common_expr(
          program, facts, available, body, function_origins,
        ),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: eliminate_local_common_expr(
          program,
          facts,
          available,
          match_.scrutinee,
          function_origins,
        ),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: eliminate_local_common_expr(
            program,
            facts,
            available,
            alternative.body,
            function_origins,
          ),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => {
          eliminate_local_common_expr(
            program, facts, available, payload, function_origins,
          )
        }),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: eliminate_local_common_expr(
          program,
          facts,
          available,
          handle.body,
          function_origins,
        ),
        final_body: eliminate_local_common_expr(
          program,
          facts,
          available,
          handle.final_body,
          function_origins,
        ),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: eliminate_local_common_expr(
              program,
              facts,
              [],
              operation.body,
              function_origins,
            ),
          }),
        }),
      })
  }
}

///|
fn simplify_program_once(
  program : @buslane.Program,
  analysis : CoreAnalysis,
  preserved_roots : Array[@buslane.ValueId],
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  let facts = @buslane.ExpressionFactsQuery::new(program)
  let substitutions = collect_top_aliases(program, preserved_roots)
  let terms = []
  for term in program.terms {
    match term {
      Let(value, _) if substitutions.has_substitution(value) => ()
      Let(value, rhs) =>
        terms.push(
          @buslane.TopTerm::Let(
            value,
            simplify_expr(
              program, facts, analysis, substitutions, rhs, function_origins, observe,
            ),
          ),
        )
      LetRec(bindings) =>
        terms.push(
          LetRec(
            bindings.map(binding => {
              ..binding,
              rhs: simplify_expr(
                program,
                facts,
                analysis,
                substitutions,
                binding.rhs,
                function_origins,
                observe,
              ),
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
) -> Array[ValueSubstitution] raise CoreOptimizeError {
  let substitutions = []
  for term in program.terms {
    guard term is Let(value, Ref(target)) else { continue }
    if !preserved_roots.contains(value) &&
      compatible_alias(program, value, target) {
      substitutions.push({ value, replacement: Ref(target), })
    }
  }
  substitutions
}

///|
fn compatible_alias(
  program : @buslane.Program,
  value : @buslane.ValueId,
  target : @buslane.ValueId,
) -> Bool raise CoreOptimizeError {
  guard program.metadata.value_info(value) is Some(value_info) else {
    return false
  }
  guard program.metadata.value_info(target) is Some(target_info) else {
    return false
  }
  core_types_definitionally_equal(
    program.metadata,
    value_info.type_,
    target_info.type_,
  )
}

///|
fn simplify_expr(
  program : @buslane.Program,
  facts : @buslane.ExpressionFactsQuery,
  analysis : CoreAnalysis,
  substitutions : Array[ValueSubstitution],
  expression : @buslane.Expr,
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Expr raise CoreOptimizeError {
  match expression {
    Ref(value) => substitutions.resolve_ref(value)
    Literal(_) => expression
    Function(function) => {
      let rewritten : @buslane.FunctionExpr = {
        ..function,
        body: simplify_expr(
          program,
          facts,
          analysis,
          substitutions,
          function.body,
          function_origins,
          observe,
        ),
      }
      transfer_function_origin(function_origins, function, rewritten)
      Function(rewritten)
    }
    Call(callee, arguments) => {
      let callee = simplify_expr(
        program, facts, analysis, substitutions, callee, function_origins, observe,
      )
      let arguments = arguments.map(argument => {
        simplify_expr(
          program, facts, analysis, substitutions, argument, function_origins, observe,
        )
      })
      simplify_call(
        program, facts, analysis, substitutions, callee, arguments, function_origins,
        observe,
      )
    }
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters,
        simplify_expr(
          program, facts, analysis, substitutions, body, function_origins, observe,
        ),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        simplify_expr(
          program, facts, analysis, substitutions, callee, function_origins, observe,
        ),
        arguments,
      )
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          simplify_expr(
            program, facts, analysis, substitutions, payload, function_origins, observe,
          )
        }),
      })
    Let(value, initializer, body) => {
      let original_initializer = initializer
      let initializer = simplify_expr(
        program, facts, analysis, substitutions, initializer, function_origins, observe,
      )
      let can_substitute = match initializer {
        Ref(target) => compatible_alias(program, value, target)
        Literal(_) => true
        _ => false
      }
      if can_substitute {
        let nested = substitutions.copy()
        nested.push({ value, replacement: initializer, })
        simplify_expr(
          program, facts, analysis, nested, body, function_origins, observe,
        )
      } else {
        let body = simplify_expr(
          program, facts, analysis, substitutions, body, function_origins, observe,
        )
        if initializer is Construct(construct) &&
          scalar_replace_local_construct(value, construct, body)
          is Some(reduced) {
          return reduced
        }
        if count_value_uses(body, value) == 0 &&
          expression_has_empty_effect(facts, original_initializer) {
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
          rhs: simplify_expr(
            program,
            facts,
            analysis,
            substitutions,
            binding.rhs,
            function_origins,
            observe,
          ),
        }),
        simplify_expr(
          program, facts, analysis, substitutions, body, function_origins, observe,
        ),
      )
    Match(match_) => {
      let scrutinee = simplify_expr(
        program,
        facts,
        analysis,
        substitutions,
        match_.scrutinee,
        function_origins,
        observe,
      )
      let alternatives = match_.alternatives.map(alternative => {
        ..alternative,
        body: simplify_expr(
          program,
          facts,
          analysis,
          substitutions,
          alternative.body,
          function_origins,
          observe,
        ),
      })
      let rewritten = @buslane.Expr::Match({
        ..match_,
        scrutinee,
        alternatives,
      })
      match known_match_reduction(analysis, rewritten) {
        Some(reduced) =>
          simplify_expr(
            program, facts, analysis, substitutions, reduced, function_origins, observe,
          )
        None => rewritten
      }
    }
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => {
          simplify_expr(
            program, facts, analysis, substitutions, payload, function_origins, observe,
          )
        }),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: simplify_expr(
          program,
          facts,
          analysis,
          substitutions,
          handle.body,
          function_origins,
          observe,
        ),
        final_body: simplify_expr(
          program,
          facts,
          analysis,
          substitutions,
          handle.final_body,
          function_origins,
          observe,
        ),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: simplify_expr(
              program,
              facts,
              analysis,
              substitutions,
              operation.body,
              function_origins,
              observe,
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
  facts : @buslane.ExpressionFactsQuery,
  analysis : CoreAnalysis,
  substitutions : Array[ValueSubstitution],
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Expr raise CoreOptimizeError {
  guard callee is Function(function) else { return Call(callee, arguments) }
  let site = ApplicationReductionSite::DirectFunction
  observe(ApplicationConsidered(site))
  let original = @buslane.Expr::Call(callee, arguments)
  let nested_observations : Array[CoreOptimizationObservation] = []
  let reduced = reduce_application(
    program,
    facts,
    analysis,
    substitutions,
    function.parameters,
    arguments,
    function.body,
    function_origins,
    observation => nested_observations.push(observation),
  )
  if application_reduction_is_profitable(original, reduced.expression, analysis) {
    for observation in nested_observations {
      observe(observation)
    }
    observe(
      ApplicationAccepted(
        site~,
        empty_arguments=reduced.empty_argument_count,
        materialized_arguments=reduced.materialized_argument_count,
      ),
    )
    reduced.expression
  } else {
    observe(ApplicationRejected(site, Profitability))
    original
  }
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
  analysis : CoreAnalysis,
  expression : @buslane.Expr,
) -> @buslane.Expr? {
  guard expression is Match(match_) else { return None }
  match match_.scrutinee {
    Construct(construct) => reduce_constructor_match(match_, construct)
    Ref(value) =>
      match analysis.find_static_value(value) {
        Some(StaticConstructor(construct)) if match_.alternatives.all(alternative => {
            count_value_uses(alternative.body, match_.binder) == 0
          }) => reduce_static_constructor_projection(match_, construct)
        Some(StaticLiteral(literal)) => reduce_literal_match(match_, literal)
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
      Construct({ ..construct, payloads: payload_refs, }),
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
