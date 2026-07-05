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
      generic_arguments~,
      variant~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) => {
      let actual = self.synthesize_variant_call(
        scope,
        type_name,
        generic_arguments,
        variant,
        variant_generic_arguments,
        reference,
        arguments,
        Some(expected),
        loc,
      )
      self.expect_type(expected, actual, loc)
    }
    Call(callee~, arguments~, loc~) =>
      self.check_call(scope, callee, arguments, expected, loc)
    StructLiteral(type_name~, generic_arguments~, fields~, loc~) => {
      let actual = self.synthesize_checked_struct_literal(
          scope,
          type_name,
          generic_arguments,
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
      generic_arguments~,
      variant~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.synthesize_variant_call(
        scope,
        type_name,
        generic_arguments,
        variant,
        variant_generic_arguments,
        reference,
        arguments,
        None,
        loc,
      )
    Call(callee~, arguments~, loc~) =>
      self.synthesize_call(scope, callee, arguments, loc)
    EffectOperationCall(name~, generic_witnesses~, arguments~, loc~) => {
      let operation = self.check_operation_call(
        scope,
        name,
        generic_witnesses,
        arguments,
        None,
        loc,
      )
      operation.result
    }
    GenericApplication(callee~, arguments~, loc~) => {
      let callee_type = self.synthesize_expr(scope, callee)
      match
        self.check_explicit_generic_application(
          scope, callee_type, arguments, loc,
        ) {
        Some(application) => application.type_
        None => Error
      }
    }
    Handler(body~, handlers~, final_branch~, loc~) =>
      self.synthesize_checked_handler(scope, body, handlers, final_branch, loc).type_
    Field(base~, name~, reference~, loc~) =>
      self.synthesize_field(scope, base, name, reference, loc)
    StructLiteral(type_name~, generic_arguments~, fields~, loc~) =>
      self.synthesize_struct_literal(
        scope, type_name, generic_arguments, fields, loc,
      )
    Builtin(_, loc~) => {
      self.report_application_inference_failure("builtin", Builtin, loc)
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
