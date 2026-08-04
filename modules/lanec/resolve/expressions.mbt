///|
/// Resolves a source expression under the current value and type scopes.
///
/// Example: `Point::{ x: a }` resolves field initializer `a` as an expression,
/// while `point.x` defers or records the field symbol depending on base type.
fn @syntax.Expr::resolve_expr(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  match self {
    IntegerLiteral(value, suffix~, loc~) => IntegerLiteral(value, suffix~, loc~)
    FloatingLiteral(value, suffix~, loc~) =>
      FloatingLiteral(value, suffix~, loc~)
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    CharLiteral(value, loc~) => CharLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    UnitLiteral(loc~) => UnitLiteral(loc~)
    Var(name, loc~) =>
      resolver.resolve_unqualified_name_use(scope, name, loc, BareUse(loc))
    QualifiedVariant(
      owner~,
      variant~,
      variant_loc~,
      variant_type_arguments~,
      arguments~,
      loc~
    ) => {
      let resolved_owner = resolve_owner_generic_arguments(
        owner, resolver, scope,
      )
      QualifiedVariant(
        type_name=resolved_owner.type_name,
        type_name_loc=owner.loc(),
        generic_arguments=resolved_owner.arguments,
        variant~,
        variant_loc~,
        variant_generic_arguments=variant_type_arguments.map(fn(type_) {
          type_.resolve_generic_argument(resolver, scope)
        }),
        reference=resolver.variant_reference(
          resolved_owner.type_name,
          variant,
          owner.loc(),
          variant_loc,
        ),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    }
    StructLiteral(owner~, fields~, loc~) => {
      let resolved_owner = resolve_owner_generic_arguments(
        owner, resolver, scope,
      )
      StructLiteral(
        type_name=resolved_owner.type_name,
        type_name_loc=owner.loc(),
        reference=resolver.type_reference(resolved_owner.type_name, owner.loc()),
        generic_arguments=resolved_owner.arguments,
        fields=resolve_struct_literal_fields(fields, resolver, scope),
        loc~,
      )
    }
    ListLiteral(_) => self.resolve_list_literal(resolver, scope)
    TupleLiteral(_) => self.resolve_tuple_literal(resolver, scope)
    Derive(capability~, target~, arguments~, source~) =>
      Derive(
        capability=capability.resolve_type(resolver, scope),
        target=target.resolve_type(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_call_argument(resolver, scope)
        }),
        source~,
      )
    Builtin(name, loc~) => Builtin(name, loc~)
    Extern(name, loc~) => Extern(name, loc~)
    EffectOperationCall(name~, type_witnesses~, arguments~, loc~) =>
      EffectOperationCall(
        name=name.resolve_effect_operation_name(resolver, scope),
        generic_witnesses=type_witnesses.map(fn(type_) {
          type_.resolve_generic_argument(resolver, scope)
        }),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    TypeApplication(callee~, arguments~, loc~) =>
      GenericApplication(
        callee=callee.resolve_expr(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_generic_argument(resolver, scope)
        }),
        loc~,
      )
    Handler(body~, handlers~, final_branch~, loc~) =>
      Handler(
        body=body.resolve_expr(resolver, scope),
        handlers=handlers.map(fn(handler) {
          handler.resolve_handler_with_block(resolver, scope)
        }),
        final_branch=final_branch.resolve_handler_final_branch(resolver, scope),
        loc~,
      )
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        type_parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      let resolved_parameters = parameters.map(fn(parameter) {
        parameter.resolve_function_literal_parameter(resolver, next_scope)
      })
      // Function literal parameters are inserted before the body is resolved;
      // omitted parameter types stay unresolved until semantic checking.
      FunctionLiteral(
        type_parameters=resolved_type_parameters,
        parameters=resolved_parameters,
        return_type=return_type.map(fn(type_) {
          type_.resolve_type(resolver, next_scope)
        }),
        effect=effect.map(fn(effect) {
          effect.resolve_effect_term(resolver, next_scope)
        }),
        body=body.resolve_expr(resolver, next_scope),
        loc~,
      )
    }
    Block(items~, result~, loc~) => {
      let next_scope = scope.enter_scope()
      // Local items are resolved in source order against one mutable scope copy.
      // This preserves sequential local bindings while still letting later items
      // see earlier `let`, `fn`, and `offer` declarations.
      Block(
        items=items.map(fn(item) {
          item.resolve_local_item(resolver, next_scope)
        }),
        result=result.resolve_expr(resolver, next_scope),
        loc~,
      )
    }
    If(condition~, then_branch~, else_branch~, loc~) =>
      If(
        condition=condition.resolve_expr(resolver, scope),
        then_branch=then_branch.resolve_expr(resolver, scope),
        else_branch=else_branch.map(fn(branch) {
          branch.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    Match(scrutinee~, arms~, loc~) =>
      Match(
        scrutinee=scrutinee.resolve_expr(resolver, scope),
        arms=arms.map(fn(arm) { arm.resolve_match_arm(resolver, scope) }),
        loc~,
      )
    Call(callee~, arguments~, loc~) =>
      callee.resolve_call(resolver, scope, arguments, loc)
    Field(loc~, ..) as field =>
      match resolver.resolve_module_value_field_chain(scope, field, loc) {
        Some(expr) => expr
        None => {
          guard field is Field(base~, name~, name_loc~, ..) else {
            abort("expected field")
          }
          let base = base.resolve_expr(resolver, scope)
          Field(
            base~,
            name~,
            name_loc~,
            reference=resolver.field_reference(scope, base, name, loc),
            loc~,
          )
        }
      }
    Unary(operator=Neg, operand=IntegerLiteral(raw, suffix~, ..), loc~) =>
      ImmediatelyNegatedIntegerLiteral(raw, suffix~, loc~)
    Unary(operator=Neg, operand=FloatingLiteral(raw, suffix~, ..), loc~) =>
      ImmediatelyNegatedFloatingLiteral(raw, suffix~, loc~)
    Unary(operator~, operand~, loc~) => {
      let target = resolver.operator_target(
        scope,
        operator.operation_name(),
        loc,
      )
      Unary(
        operator~,
        target~,
        operand=operand.resolve_expr(resolver, scope),
        loc~,
      )
    }
    Binary(operator~, left~, right~, loc~) => {
      let target = resolver.operator_target(
        scope,
        operator.operation_name(),
        loc,
      )
      Binary(
        operator~,
        target~,
        left=left.resolve_expr(resolver, scope),
        right=right.resolve_expr(resolver, scope),
        loc~,
      )
    }
    Pipeline(left~, right~, loc~) =>
      Pipeline(
        left=left.resolve_expr(resolver, scope),
        right=right.resolve_expr(resolver, scope),
        loc~,
      )
    Grouped(expression~, ..) => expression.resolve_expr(resolver, scope)
  }
}

///|
fn @syntax.EffectOperationName::resolve_effect_operation_name(
  self : @syntax.EffectOperationName,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectOperationName {
  match self {
    Qualified(owner~, operation~, operation_loc~) => {
      let owner = owner.resolve_effect_type(resolver, scope, owner.loc())
      let reference = match owner {
        Singleton(symbol~, ..) => {
          resolver.record_import_use(
            resolver.effect_import_origin(symbol),
            operation_loc,
          )
          resolver.operation_reference(symbol, operation)
        }
        _ => Unresolved(operation)
      }
      Qualified(owner~, operation~, reference~, operation_loc~)
    }
    Unqualified(operation~, operation_loc~) =>
      Unqualified(
        operation~,
        reference=resolver.unqualified_operation_reference(
          operation, operation_loc,
        ),
        operation_loc~,
      )
  }
}

///|
/// Resolves call syntax whose callee was parsed as an expression.
///
/// Example: `f(x)` resolves to a value call when `f` is visible as a value,
/// while `some(x)` resolves to an unqualified enum variant call when no value
/// named `some` is visible and enum variants named `some` are available.
fn @syntax.Expr::resolve_call(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
  arguments : Array[@syntax.CallArgument],
  loc : SourceSpan,
) -> ResolvedExpr {
  match self {
    TypeApplication(
      callee=Var(name, loc=name_loc),
      arguments=type_arguments,
      ..
    ) =>
      match scope.value_reference(name) {
        Symbol(_) =>
          Call(
            callee=self.resolve_expr(resolver, scope),
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
        Unresolved(_) =>
          resolver.resolve_unqualified_name_use_with_variant_arguments(
            scope,
            name,
            name_loc,
            CallUse(arguments~, loc~),
            type_arguments,
          )
      }
    Var(name, loc=name_loc) =>
      resolver.resolve_unqualified_name_use(
        scope,
        name,
        name_loc,
        CallUse(arguments~, loc~),
      )
    Field(..) =>
      match resolver.resolve_module_value_field_chain(scope, self, self.loc()) {
        Some(callee) =>
          Call(
            callee~,
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
        None =>
          Call(
            callee=self.resolve_expr(resolver, scope),
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
      }
    _ =>
      Call(
        callee=self.resolve_expr(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
/// Resolves the expression carried by a call argument.
///
/// Example: `op_add(1, 2, op=custom)` preserves the `custom` expression for
/// later contextual-argument checking. Full named argument validation belongs
/// to the type checker because it needs callee metadata.
fn @syntax.CallArgument::resolve_call_argument(
  self : @syntax.CallArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedCallArgument {
  match self {
    Positional(value~, loc~) =>
      Positional(value=value.resolve_expr(resolver, scope), loc~)
    Named(name~, value~, loc~) =>
      Named(name~, value=value.resolve_expr(resolver, scope), loc~)
  }
}

///|
/// Resolves a call argument in a syntactic position that only accepts
/// positional values.
///
/// Example: variant construction accepts `some(x)`, while named contextual
/// arguments are reserved for direct function calls and are therefore reduced
/// to their value expression here.
fn @syntax.CallArgument::resolve_positional_call_argument(
  self : @syntax.CallArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  match self {
    Positional(value~, ..) => value.resolve_expr(resolver, scope)
    Named(value~, ..) => value.resolve_expr(resolver, scope)
  }
}

///|
/// Resolves one struct literal field value or field pun.
///
/// Example: `Point::{ x }` records the visible value reference for `x`, while
/// `Point::{ x: value }` resolves `value` now.
fn @syntax.StructLiteralField::resolve_struct_literal_field(
  self : @syntax.StructLiteralField,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedStructLiteralField {
  match self {
    Value(name~, value~, loc~) => {
      let punned_reference = match value {
        Some(_) => None
        None => {
          let reference = scope.value_reference(name)
          resolver.record_import_use(scope.value_import_origin(reference), loc)
          resolver.report_unresolved_value(reference, loc)
          Some(reference)
        }
      }
      Value(
        name~,
        value=value.map(fn(value) { value.resolve_expr(resolver, scope) }),
        punned_reference~,
        loc~,
      )
    }
    TypeWitness(name~, witness~, loc~) =>
      TypeWitness(
        name~,
        witness=witness.resolve_generic_argument(resolver, scope),
        loc~,
      )
  }
}

///|
fn resolve_struct_literal_fields(
  fields : Array[@syntax.StructLiteralField],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedStructLiteralField] {
  fields.map(fn(field) { field.resolve_struct_literal_field(resolver, scope) })
}

///|
/// Resolves a function literal parameter and binds it in the literal body scope.
///
/// Example: in `fn(x) { x }`, `x` gets a value symbol even when its type
/// annotation is absent and must be inferred later from context.
fn @syntax.FunctionLiteralParameter::resolve_function_literal_parameter(
  self : @syntax.FunctionLiteralParameter,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedFunctionLiteralParameter {
  let type_annotation = self.type_annotation.map(fn(type_) {
    type_.resolve_type(resolver, scope)
  })
  let symbol = resolver.registry.define_value(
    self.name,
    Parameter,
    self.name_loc,
  )
  scope.define_value(self.name, symbol, type_annotation)
  {
    symbol,
    is_offered: self.is_offered,
    name: self.name,
    name_loc: self.name_loc,
    type_annotation,
    loc: self.loc,
  }
}

///|
/// Resolves a local block item in source order.
///
/// Example: a local `let` extends the following scope, and a local `fn` binds
/// its name before resolving its body.
fn @syntax.LocalItem::resolve_local_item(
  self : @syntax.LocalItem,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedLocalItem {
  match self {
    Let(declaration) =>
      Let(declaration.resolve_let(resolver, scope, LocalBinding))
    PatternLet(declaration) =>
      PatternLet(declaration.resolve_pattern_let(resolver, scope))
    Function(declaration) => {
      let symbol = resolver.registry.define_value(
        declaration.name,
        LocalFunction,
        declaration.loc,
      )
      scope.define_value(declaration.name, symbol, None)
      // The local function name is inserted before its body is resolved, so the
      // function can call itself after the declaration has been reached.
      Function(
        declaration.resolve_function_with_symbol(resolver, symbol, scope),
      )
    }
    Expression(expression~) =>
      Expression(expression.resolve_expr(resolver, scope))
  }
}

///|
fn @syntax.PatternLetDeclaration::resolve_pattern_let(
  self : @syntax.PatternLetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPatternLetDeclaration {
  let initializer = self.initializer.resolve_expr(resolver, scope)
  let type_annotation = self.type_annotation.map(fn(type_) {
    type_.resolve_type(resolver, scope)
  })
  let pattern = self.pattern.resolve_pattern(resolver, scope)
  { pattern, type_annotation, initializer, loc: self.loc }
}

///|
/// Resolves a match arm with pattern binders visible only in the arm body.
///
/// Example: in `Option::some(x) => x`, the pattern binder `x` is added to a
/// copied arm scope before resolving the body expression.
fn @syntax.MatchArm::resolve_match_arm(
  self : @syntax.MatchArm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedMatchArm {
  let arm_scope = scope.copy()
  {
    pattern: self.pattern.resolve_pattern(resolver, arm_scope),
    body: self.body.resolve_expr(resolver, arm_scope),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerWithBlock::resolve_handler_with_block(
  self : @syntax.HandlerWithBlock,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerWithBlock {
  {
    arms: self.arms.map(fn(arm) {
      arm.resolve_handler_operation_arm(resolver, scope)
    }),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerOperationArm::resolve_handler_operation_arm(
  self : @syntax.HandlerOperationArm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerOperationArm {
  let arm_scope = scope.copy()
  let type_binders = resolver.resolve_type_parameter_names(
    self.type_binders.map(fn(binder) { binder.name }),
    self.loc,
  )
  arm_scope.type_parameters.append(type_binders)
  let payload_patterns = self.payload_patterns.map(fn(pattern) {
    pattern.resolve_pattern(resolver, arm_scope)
  })
  let resume_symbol = resolver.registry.define_value(
    self.resume_binder,
    PatternBinder,
    self.resume_loc,
  )
  arm_scope.define_value(self.resume_binder, resume_symbol, None)
  {
    name: self.name.resolve_effect_operation_name(resolver, scope),
    type_binders,
    payload_patterns,
    resume_symbol,
    resume_binder: self.resume_binder,
    resume_loc: self.resume_loc,
    body: self.body.resolve_expr(resolver, arm_scope),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerFinalBranch::resolve_handler_final_branch(
  self : @syntax.HandlerFinalBranch,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerFinalBranch {
  let branch_scope = scope.copy()
  let binder_symbol = resolver.registry.define_value(
    self.binder,
    PatternBinder,
    self.binder_loc,
  )
  branch_scope.define_value(self.binder, binder_symbol, None)
  {
    binder_symbol,
    binder: self.binder,
    binder_loc: self.binder_loc,
    body: self.body.resolve_expr(resolver, branch_scope),
    loc: self.loc,
  }
}
