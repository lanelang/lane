///|
priv struct RuntimeEffectExternal {
  operation : @buslane.OperationId
  value : @buslane.ValueId
}

///|
fn erase_effects_before_anf(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  operations : Array[@artifact_core.LinkedRuntimeEffectOperation],
) -> (@buslane.Program, @buslane_lowering.BuslaneExternalMap) raise LoisvmLoweringError {
  let bindings : Array[RuntimeEffectExternal] = []
  let terms = program.terms.copy()
  let builtins = externals.builtins.copy()
  for operation in operations {
    let info = match program.metadata.operation_info(operation.operation) {
      Some(info) => info
      None =>
        raise UnsupportedExpression(
          detail="linked runtime effect operation metadata is missing",
        )
    }
    if !info.hidden_type_parameters.is_empty() {
      raise UnsupportedExpression(
        detail="generic runtime effect operations are outside the v1 primitive host ABI",
      )
    }
    let type_ = @buslane.Type::Function(
      info.payload_types,
      info.result_type,
      Empty,
    )
    if !runtime_import_signature_supported(type_) {
      raise UnsupportedExpression(
        detail="runtime effect operations must use only v1 host primitive types",
      )
    }
    let value = program.metadata.define_value(
      "%runtime_effect_\{operation.operation.index}",
      External,
      type_,
    )
    bindings.push({ operation: operation.operation, value })
    terms.push(External(value))
    builtins.push({ value, name: runtime_effect_symbol(operation), type_ })
  }
  let resolved_terms = terms.map(term => {
    resolve_runtime_effect_term(term, bindings)
  })
  ({ metadata: program.metadata, terms: resolved_terms }, { builtins, })
}

///|
fn runtime_effect_symbol(
  operation : @artifact_core.LinkedRuntimeEffectOperation,
) -> String {
  "lane.effect.v1/\{operation.module_path_text}/\{operation.effect_name}/\{operation.operation_name}"
}

///|
fn resolve_runtime_effect_term(
  term : @buslane.TopTerm,
  bindings : Array[RuntimeEffectExternal],
) -> @buslane.TopTerm raise LoisvmLoweringError {
  match term {
    Let(value, expression) =>
      Let(value, resolve_runtime_effect_expr(expression, bindings))
    LetRec(recursive) =>
      LetRec(
        recursive.map(binding => {
          ..binding,
          rhs: resolve_runtime_effect_expr(binding.rhs, bindings),
        }),
      )
    External(_) => term
  }
}

///|
fn resolve_runtime_effect_expr(
  expression : @buslane.Expr,
  bindings : Array[RuntimeEffectExternal],
) -> @buslane.Expr raise LoisvmLoweringError {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) =>
      Function({
        ..function,
        body: resolve_runtime_effect_expr(function.body, bindings),
      })
    Call(callee, arguments) =>
      Call(
        resolve_runtime_effect_expr(callee, bindings),
        arguments.map(argument => {
          resolve_runtime_effect_expr(argument, bindings)
        }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, resolve_runtime_effect_expr(body, bindings))
    TypeApply(callee, arguments) =>
      TypeApply(resolve_runtime_effect_expr(callee, bindings), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          resolve_runtime_effect_expr(payload, bindings)
        }),
      })
    Let(value, initializer, body) =>
      Let(
        value,
        resolve_runtime_effect_expr(initializer, bindings),
        resolve_runtime_effect_expr(body, bindings),
      )
    LetRec(recursive, body) =>
      LetRec(
        recursive.map(binding => {
          ..binding,
          rhs: resolve_runtime_effect_expr(binding.rhs, bindings),
        }),
        resolve_runtime_effect_expr(body, bindings),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: resolve_runtime_effect_expr(match_.scrutinee, bindings),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: resolve_runtime_effect_expr(alternative.body, bindings),
        }),
      })
    Perform(perform) => {
      if !perform.effect_arguments.is_empty() ||
        !perform.hidden_witnesses.is_empty() {
        raise UnsupportedExpression(
          detail="generic runtime effect operations are outside the v1 primitive host ABI",
        )
      }
      let target = match
        find_runtime_effect_external(bindings, perform.operation) {
        Some(value) => value
        None =>
          raise UnsupportedExpression(
            detail="non-runtime effects must be erased before VM CFG lowering",
          )
      }
      Call(
        Ref(target),
        perform.payloads.map(payload => {
          resolve_runtime_effect_expr(payload, bindings)
        }),
      )
    }
    Handle(_) =>
      raise UnsupportedExpression(
        detail="handlers must be erased before VM CFG lowering",
      )
    Resume(_) =>
      raise UnsupportedExpression(
        detail="resume must be erased before VM CFG lowering",
      )
  }
}

///|
fn find_runtime_effect_external(
  bindings : Array[RuntimeEffectExternal],
  operation : @buslane.OperationId,
) -> @buslane.ValueId? {
  for binding in bindings {
    if binding.operation == operation {
      return Some(binding.value)
    }
  }
  None
}
