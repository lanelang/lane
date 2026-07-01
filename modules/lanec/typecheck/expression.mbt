///|
fn SemanticChecker::check_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expr : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> Unit {
  // Checking judgment:
  //
  //   Gamma |- e <= Expected
  //
  // The expected type flows only to syntax nodes that are adjacent to this
  // expression: block results, if branches, function literals, calls, and
  // operators. This is the local part of LTI; it never creates global inference
  // variables to be solved elsewhere.
  match expr {
    Literal(literal~, loc~) => self.check_literal(literal, expected, loc)
    Builtin(_, ..) => ()
    Var(..) => {
      let actual = self.synthesize_expr(scope, expr)
      self.expect_type(expected, actual, expr.loc())
    }
    Block(items~, result~, ..) =>
      self.check_block(scope, items, result, expected)
    If(condition~, then_branch~, else_branch~, ..) =>
      self.check_if(scope, condition, then_branch, else_branch, expected)
    Match(scrutinee~, arms~, loc~) =>
      self.check_match(scope, scrutinee, arms, expected, loc)
    VariantCall(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      loc~
    ) => {
      let actual = self.synthesize_variant_call(
        scope,
        type_name,
        type_arguments,
        variant,
        variant_type_arguments,
        reference,
        arguments,
        Some(expected),
        loc,
      )
      self.expect_type(expected, actual, loc)
    }
    Call(callee~, arguments~, loc~) =>
      self.check_call(scope, callee, arguments, expected, loc)
    StructLiteral(type_name~, type_arguments~, fields~, loc~) => {
      let actual = self.synthesize_checked_struct_literal(
          scope,
          type_name,
          type_arguments,
          fields,
          Some(expected),
          loc,
        ).type_
      self.expect_type(expected, actual, loc)
    }
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      self.check_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, expected,
        loc,
      )
    _ => {
      let actual = self.synthesize_expr(scope, expr)
      self.expect_type(expected, actual, expr.loc())
    }
  }
}

///|
fn SemanticChecker::check_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  else_branch : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> Unit {
  // Gamma |- condition <= Bool
  // Gamma |- then <= Expected
  // Gamma |- else <= Expected
  // ---
  // Gamma |- if condition { then } else { else } <= Expected
  self.check_expr(scope, condition, Primitive(Bool))
  self.check_expr(scope, then_branch, expected)
  self.check_expr(scope, else_branch, expected)
}

///|
fn SemanticChecker::check_block(
  self : SemanticChecker,
  scope : TypeScope,
  items : Array[@desugar.DesugaredLocalItem],
  result : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> Unit {
  // Gamma |- item_1 => Gamma_1
  // ...
  // Gamma_n |- result <= Expected
  // ---
  // Gamma |- { item_1; ...; result } <= Expected
  //
  // Only the block result receives the expected type. Local items are processed
  // sequentially and extend a block-local scope.
  let next_scope = scope.copy()
  for item in items {
    match item {
      Let(declaration) => self.check_local_let(next_scope, declaration)
      Function(declaration) =>
        self.check_local_function(next_scope, declaration)
      Offer(declaration) => self.check_local_offer(next_scope, declaration)
      PatternLet(declaration) =>
        ignore(self.check_local_pattern_let(next_scope, declaration))
    }
  }
  self.check_expr(next_scope, result, expected)
}

///|
fn SemanticChecker::synthesize_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expr : @desugar.DesugaredExpr,
) -> @types.Type {
  // Synthesis judgment:
  //
  //   Gamma |- e => T
  //
  // This direction computes a type from the expression itself. If an expression
  // needs an adjacent expected type, it must be handled by `check_expr` instead
  // of inventing a non-local type.
  match expr {
    Literal(literal~, loc~) => {
      if literal is Int(raw) {
        ignore(self.check_int_literal(raw, loc))
      }
      literal.type_()
    }
    Var(name~, reference~, loc~) =>
      self.synthesize_value_reference(scope, reference, name, loc)
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      self.synthesize_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, loc,
      )
    Block(items~, result~, ..) => self.synthesize_block(scope, items, result)
    If(condition~, then_branch~, else_branch~, loc~) =>
      self.synthesize_if(scope, condition, then_branch, else_branch, loc)
    Match(scrutinee~, arms~, loc~) =>
      self.synthesize_match(scope, scrutinee, arms, loc)
    VariantCall(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.synthesize_variant_call(
        scope,
        type_name,
        type_arguments,
        variant,
        variant_type_arguments,
        reference,
        arguments,
        None,
        loc,
      )
    Call(callee~, arguments~, loc~) =>
      self.synthesize_call(scope, callee, arguments, loc)
    EffectOperationCall(name~, arguments~, loc~) => {
      let operation = self.check_operation_call(scope, name, arguments, loc)
      operation.result
    }
    Handler(body~, handlers~, final_branch~, loc~) =>
      self.synthesize_handler(scope, body, handlers, final_branch, loc)
    Field(base~, name~, reference~, loc~) =>
      self.synthesize_field(scope, base, name, reference, loc)
    StructLiteral(type_name~, type_arguments~, fields~, loc~) =>
      self.synthesize_struct_literal(
        scope, type_name, type_arguments, fields, loc,
      )
    Builtin(_, loc~) => {
      self.diagnostics.push({ kind: CannotInferExpression("builtin"), loc })
      Error
    }
  }
}

///|
fn SemanticChecker::synthesize_block(
  self : SemanticChecker,
  scope : TypeScope,
  items : Array[@desugar.DesugaredLocalItem],
  result : @desugar.DesugaredExpr,
) -> @types.Type {
  let next_scope = scope.copy()
  let opened_type_parameters : Array[TypeParameterId] = []
  for item in items {
    match item {
      Let(declaration) => self.check_local_let(next_scope, declaration)
      Function(declaration) =>
        self.check_local_function(next_scope, declaration)
      Offer(declaration) => self.check_local_offer(next_scope, declaration)
      PatternLet(declaration) => {
        let pattern = self.check_local_pattern_let(next_scope, declaration)
        opened_type_parameters.append(pattern.opened_type_parameters())
      }
    }
  }
  let type_ = self.synthesize_expr(next_scope, result)
  self.check_hidden_type_escape(opened_type_parameters, type_, result.loc())
  type_
}

///|
fn SemanticChecker::synthesize_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  else_branch : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> @types.Type {
  self.check_expr(scope, condition, Primitive(Bool))
  let then_type = self.synthesize_expr(scope, then_branch)
  let else_type = self.synthesize_expr(scope, else_branch)
  self.expect_type(then_type, else_type, loc)
  then_type
}

///|
fn SemanticChecker::synthesize_expr_effect(
  self : SemanticChecker,
  scope : TypeScope,
  expr : @desugar.DesugaredExpr,
) -> @types.Effect {
  match expr {
    Literal(..) | Var(..) | Builtin(_, ..) => Empty
    FunctionLiteral(..) => Empty
    Handler(..) => Empty
    Field(base~, ..) => self.synthesize_expr_effect(scope, base)
    StructLiteral(fields~, ..) => {
      let effects = []
      for field in fields {
        if field is Value(value~, ..) {
          effects.push(self.synthesize_expr_effect(scope, value))
        }
      }
      effect_union(effects)
    }
    VariantCall(arguments~, ..) =>
      effect_union(
        arguments.map(fn(argument) {
          self.synthesize_expr_effect(scope, argument)
        }),
      )
    Block(items~, result~, ..) => {
      let next_scope = scope.copy()
      let effects = []
      for item in items {
        match item {
          Let(declaration) => {
            effects.push(
              self.synthesize_expr_effect(next_scope, declaration.initializer),
            )
            if declaration.type_annotation is Some(type_annotation) {
              next_scope.bind(
                declaration.symbol,
                self.check_type(type_annotation),
              )
            }
          }
          Function(declaration) =>
            next_scope.bind_function(
              declaration.symbol,
              self.function_type(
                declaration.type_parameters,
                declaration.parameters,
                declaration.return_type,
                declaration.effect,
              ),
              declaration.parameters.map(fn(parameter) {
                self.checked_value_parameter(parameter)
              }),
            )
          Offer(declaration) => {
            effects.push(
              self.synthesize_expr_effect(next_scope, declaration.initializer),
            )
            let type_ = self.check_type(declaration.type_annotation)
            next_scope.bind(declaration.symbol, type_)
            self.offer_symbol(
              next_scope.offers,
              declaration.symbol,
              type_,
              declaration.loc,
            )
          }
          PatternLet(declaration) =>
            effects.push(
              self.synthesize_expr_effect(next_scope, declaration.initializer),
            )
        }
      }
      effects.push(self.synthesize_expr_effect(next_scope, result))
      effect_union(effects)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      effect_union([
        self.synthesize_expr_effect(scope, condition),
        self.synthesize_expr_effect(scope, then_branch),
        self.synthesize_expr_effect(scope, else_branch),
      ])
    Match(scrutinee~, arms~, ..) => {
      let effects = [self.synthesize_expr_effect(scope, scrutinee)]
      for arm in arms {
        effects.push(self.synthesize_expr_effect(scope, arm.body))
      }
      effect_union(effects)
    }
    Call(callee~, arguments~, ..) => {
      let callee_type = self.synthesize_expr(scope, callee)
      let effects = [self.synthesize_expr_effect(scope, callee)]
      for argument in arguments {
        effects.push(self.synthesize_expr_effect(scope, argument.value_expr()))
      }
      match callee_type {
        Function(_, _, effect) => effects.push(effect)
        Forall(type_parameters, body) =>
          match
            self.instantiate_generic_callable(
              scope,
              type_parameters,
              body,
              arguments,
              None,
              callee.loc(),
              false,
            ) {
            Some(instantiated) => effects.push(instantiated.effect)
            None => ()
          }
        _ => ()
      }
      effect_union(effects)
    }
    EffectOperationCall(name~, arguments~, loc~) => {
      let operation = self.check_operation_call(scope, name, arguments, loc)
      let effects = [operation.effect]
      for argument in arguments {
        effects.push(self.synthesize_expr_effect(scope, argument))
      }
      effect_union(effects)
    }
  }
}

///|
fn SemanticChecker::expect_type(
  self : SemanticChecker,
  expected : @types.Type,
  actual : @types.Type,
  loc : SourceSpan,
) -> Unit {
  if !type_matches(expected, actual) {
    self.diagnostics.push({ kind: TypeMismatch(expected~, actual~), loc })
  }
}

///|
fn type_matches(expected : @types.Type, actual : @types.Type) -> Bool {
  expected is Error || actual is Error || expected.equals(actual)
}
