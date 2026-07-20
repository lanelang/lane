///|
let nonescaping_inline_node_limit = 48

///|
let escaping_inline_node_limit = 16

///|
let inline_per_callee_limit = 4

///|
let whole_program_expansion_limit = 64

///|
priv struct KnownCall {
  value : @buslane.ValueId
  generic_arguments : Array[@buslane.GenericArgument]
}

///|
priv struct PartialEvaluator {
  program : @buslane.Program
  analysis : InterproceduralAnalysis
  expansions : Array[Int]
  mut remaining_expansions : Int
}

///|
fn partially_evaluate_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> @buslane.Program {
  let expansions = Array::make(program.metadata.values.length(), 0)
  let mut current = program
  let mut remaining_expansions = whole_program_expansion_limit
  for _ in 0..<2 {
    while expansions.length() < program.metadata.values.length() {
      expansions.push(0)
    }
    let evaluator : PartialEvaluator = {
      program: current,
      analysis: analyze_interprocedural(current, entry, roots),
      expansions,
      remaining_expansions,
    }
    let terms = current.terms.map(term => evaluator.rewrite_top_term(term))
    remaining_expansions = evaluator.remaining_expansions
    if terms == current.terms {
      return current
    }
    current = { ..current, terms, }
  }
  current
}

///|
fn PartialEvaluator::rewrite_top_term(
  self : PartialEvaluator,
  term : @buslane.TopTerm,
) -> @buslane.TopTerm {
  match term {
    Let(value, expression) =>
      Let(value, self.rewrite_top_level_expression(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: self.rewrite_expr(binding.rhs),
        }),
      )
    External(_) => term
  }
}

///|
fn PartialEvaluator::rewrite_top_level_expression(
  self : PartialEvaluator,
  expression : @buslane.Expr,
) -> @buslane.Expr {
  match expression {
    Call(callee, arguments) => self.rewrite_call(callee, arguments, true)
    _ => self.rewrite_expr(expression)
  }
}

///|
fn PartialEvaluator::rewrite_expr(
  self : PartialEvaluator,
  expression : @buslane.Expr,
) -> @buslane.Expr {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) =>
      Function({ ..function, body: self.rewrite_expr(function.body) })
    Call(callee, arguments) => self.rewrite_call(callee, arguments, false)
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.rewrite_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(self.rewrite_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => self.rewrite_expr(payload)),
      })
    Let(value, initializer, body) =>
      Let(value, self.rewrite_expr(initializer), self.rewrite_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: self.rewrite_expr(binding.rhs),
        }),
        self.rewrite_expr(body),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: self.rewrite_expr(match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: self.rewrite_expr(alternative.body),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => self.rewrite_expr(payload)),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: self.rewrite_expr(handle.body),
        final_body: self.rewrite_expr(handle.final_body),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: self.rewrite_expr(operation.body),
          }),
        }),
      })
  }
}

///|
fn PartialEvaluator::rewrite_call(
  self : PartialEvaluator,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
  allow_constructor_materialization : Bool,
) -> @buslane.Expr {
  let callee = self.rewrite_expr(callee)
  let arguments = arguments.map(argument => self.rewrite_expr(argument))
  match
    self.try_inline_known_call(
      callee, arguments, allow_constructor_materialization,
    ) {
    Some(inlined) => inlined
    None => Call(callee, arguments)
  }
}

///|
fn PartialEvaluator::try_inline_known_call(
  self : PartialEvaluator,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
  allow_constructor_materialization : Bool,
) -> @buslane.Expr? {
  guard known_call(callee) is Some(call) &&
    self.analysis.find_callable(call.value) is Some(callable) &&
    !callable.recursive &&
    callable_effect_is_empty(self.program, callable.value) &&
    callable_body_is_inlineable(callable.function.body) &&
    arguments.all(is_substitutable_atom) &&
    callable.function.parameters.length() == arguments.length() &&
    callable.type_parameters.length() == call.generic_arguments.length() &&
    !has_dynamic_parameter_match(
      callable.function.body,
      callable.function.parameters,
      arguments,
      self.analysis.core,
    ) else {
    return None
  }
  let node_limit = if callable.occurrence.escapes {
    escaping_inline_node_limit
  } else {
    nonescaping_inline_node_limit
  }
  let replaced_size = 1 +
    core_expression_size(callee) +
    arguments.fold(init=0, fn(size, argument) {
      size + core_expression_size(argument)
    })
  if callable.expression_size > node_limit ||
    self.expansions[callable.value.index] >= inline_per_callee_limit ||
    self.remaining_expansions == 0 {
    return None
  }
  guard InlineCloneContext::from_application(
      self.program.metadata,
      callable.type_parameters,
      call.generic_arguments,
    )
    is Some(clone_context) else {
    return None
  }
  let cloned = clone_context.clone_function(callable.function)
  let substitutions = []
  for index in 0..<arguments.length() {
    substitutions.push({
      value: cloned.parameters[index],
      replacement: arguments[index],
    })
  }
  let reduced = simplify_expr(
    self.program,
    self.analysis.core,
    substitutions,
    cloned.body,
  )
  let speculative : PartialEvaluator = {
    program: self.program,
    analysis: self.analysis,
    expansions: self.expansions.copy(),
    remaining_expansions: self.remaining_expansions - 1,
  }
  speculative.expansions[callable.value.index] += 1
  let candidate = speculative.rewrite_expr(reduced)
  let candidate_is_profitable = core_expression_size(candidate) < replaced_size ||
    (allow_constructor_materialization && candidate is Construct(_))
  if !candidate_is_profitable {
    return None
  }
  for index in 0..<self.expansions.length() {
    self.expansions[index] = speculative.expansions[index]
  }
  self.remaining_expansions = speculative.remaining_expansions
  Some(candidate)
}

///|
fn has_dynamic_parameter_match(
  expression : @buslane.Expr,
  parameters : Array[@buslane.ValueId],
  arguments : Array[@buslane.Expr],
  core : CoreAnalysis,
) -> Bool {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => false
    Function(function) =>
      has_dynamic_parameter_match(function.body, parameters, arguments, core)
    Call(callee, call_arguments) =>
      has_dynamic_parameter_match(callee, parameters, arguments, core) ||
      call_arguments.any(argument => {
        has_dynamic_parameter_match(argument, parameters, arguments, core)
      })
    TypeLambda(_, body) | TypeApply(body, _) =>
      has_dynamic_parameter_match(body, parameters, arguments, core)
    Construct(construct) =>
      construct.payloads.any(payload => {
        has_dynamic_parameter_match(payload, parameters, arguments, core)
      })
    Let(_, initializer, body) =>
      has_dynamic_parameter_match(initializer, parameters, arguments, core) ||
      has_dynamic_parameter_match(body, parameters, arguments, core)
    LetRec(bindings, body) =>
      bindings.any(binding => {
        has_dynamic_parameter_match(binding.rhs, parameters, arguments, core)
      }) ||
      has_dynamic_parameter_match(body, parameters, arguments, core)
    Match(match_) => {
      if referenced_value(match_.scrutinee) is Some(scrutinee) &&
        find_value_index(parameters, scrutinee) is Some(index) &&
        !is_statically_deconstructable(arguments[index], core, []) {
        return true
      }
      has_dynamic_parameter_match(match_.scrutinee, parameters, arguments, core) ||
      match_.alternatives.any(alternative => {
        has_dynamic_parameter_match(
          alternative.body,
          parameters,
          arguments,
          core,
        )
      })
    }
    Perform(perform) =>
      perform.payloads.any(payload => {
        has_dynamic_parameter_match(payload, parameters, arguments, core)
      })
    Handle(handle) =>
      has_dynamic_parameter_match(handle.body, parameters, arguments, core) ||
      has_dynamic_parameter_match(
        handle.final_body,
        parameters,
        arguments,
        core,
      ) ||
      handle.handlers.any(table => {
        table.operations.any(operation => {
          has_dynamic_parameter_match(
            operation.body,
            parameters,
            arguments,
            core,
          )
        })
      })
  }
}

///|
fn find_value_index(
  values : Array[@buslane.ValueId],
  value : @buslane.ValueId,
) -> Int? {
  for index, candidate in values {
    if candidate == value {
      return Some(index)
    }
  }
  None
}

///|
fn is_statically_deconstructable(
  expression : @buslane.Expr,
  core : CoreAnalysis,
  visited : Array[@buslane.ValueId],
) -> Bool {
  match expression {
    Literal(_) | Construct(_) => true
    Ref(value) => {
      if visited.contains(value) {
        return false
      }
      guard core.find_top_definition(value) is Some(definition) else {
        return false
      }
      let next_visited = visited.copy()
      next_visited.push(value)
      is_statically_deconstructable(definition, core, next_visited)
    }
    TypeApply(callee, _) => is_statically_deconstructable(callee, core, visited)
    _ => false
  }
}

///|
fn known_call(expression : @buslane.Expr) -> KnownCall? {
  match expression {
    Ref(value) => Some({ value, generic_arguments: [] })
    TypeApply(callee, arguments) => {
      guard known_call(callee) is Some(call) else { return None }
      Some({
        value: call.value,
        generic_arguments: call.generic_arguments + arguments,
      })
    }
    _ => None
  }
}

///|
fn callable_effect_is_empty(
  program : @buslane.Program,
  value : @buslane.ValueId,
) -> Bool {
  guard program.metadata.value_info(value) is Some(info) else { return false }
  match strip_type_quantifiers(info.type_) {
    Function(_, _, Empty) => true
    _ => false
  }
}

///|
fn strip_type_quantifiers(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Forall(_, body) | TypeLambda(_, body) => strip_type_quantifiers(body)
    _ => type_
  }
}

///|
fn callable_body_is_inlineable(expression : @buslane.Expr) -> Bool {
  match expression {
    Ref(_) | Literal(_) => true
    Resume(_) | Perform(_) | Handle(_) => false
    Function(function) => callable_body_is_inlineable(function.body)
    Call(callee, arguments) =>
      callable_body_is_inlineable(callee) &&
      arguments.all(callable_body_is_inlineable)
    TypeLambda(_, _) => false
    TypeApply(body, _) => callable_body_is_inlineable(body)
    Construct(construct) => construct.payloads.all(callable_body_is_inlineable)
    Let(_, initializer, body) =>
      callable_body_is_inlineable(initializer) &&
      callable_body_is_inlineable(body)
    LetRec(bindings, body) =>
      bindings.all(binding => callable_body_is_inlineable(binding.rhs)) &&
      callable_body_is_inlineable(body)
    Match(match_) =>
      match_.alternatives.all(alternative => {
        alternative.type_binders.is_empty() &&
        callable_body_is_inlineable(alternative.body)
      }) &&
      callable_body_is_inlineable(match_.scrutinee)
  }
}
