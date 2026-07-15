///|
pub fn CheckedExpr::substitute(
  self : CheckedExpr,
  substitution : @types.TypeSubstitution,
) -> CheckedExpr {
  match self {
    Literal(literal~, type_~, loc~) =>
      Literal(literal~, type_=type_.substitute(substitution), loc~)
    Value(name~, symbol~, type_~, loc~) =>
      Value(name~, symbol~, type_=type_.substitute(substitution), loc~)
    CompilerIntrinsic(name~, type_~, loc~) =>
      CompilerIntrinsic(name~, type_=type_.substitute(substitution), loc~)
    ExternBinding(name~, type_~, loc~) =>
      ExternBinding(name~, type_=type_.substitute(substitution), loc~)
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      body~,
      type_~,
      loc~
    ) =>
      FunctionLiteral(
        type_parameters~,
        parameters=substitute_value_parameters(parameters, substitution),
        return_type=return_type.substitute(substitution),
        body=body.substitute(substitution),
        type_=type_.substitute(substitution),
        loc~,
      )
    GenericApplication(callee~, arguments~, type_~, loc~) =>
      GenericApplication(
        callee=callee.substitute(substitution),
        arguments=arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        type_=type_.substitute(substitution),
        loc~,
      )
    Block(items~, result~, type_~, loc~) =>
      Block(
        items=items.map(fn(item) { item.substitute(substitution) }),
        result=result.substitute(substitution),
        type_=type_.substitute(substitution),
        loc~,
      )
    If(condition~, then_branch~, else_branch~, type_~, loc~) =>
      If(
        condition=condition.substitute(substitution),
        then_branch=then_branch.substitute(substitution),
        else_branch=else_branch.substitute(substitution),
        type_=type_.substitute(substitution),
        loc~,
      )
    Match(scrutinee~, arms~, type_~, loc~) =>
      Match(
        scrutinee=scrutinee.substitute(substitution),
        arms=arms.map(fn(arm) { arm.substitute(substitution) }),
        type_=type_.substitute(substitution),
        loc~,
      )
    Call(callee~, arguments~, type_~, loc~) =>
      Call(
        callee=callee.substitute(substitution),
        arguments=arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        type_=type_.substitute(substitution),
        loc~,
      )
    OperationCall(
      operation~,
      generic_witnesses~,
      arguments~,
      effect~,
      type_~,
      loc~
    ) =>
      OperationCall(
        operation~,
        generic_witnesses=generic_witnesses.map(fn(witness) {
          witness.substitute(substitution)
        }),
        arguments=arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        effect=effect.substitute(substitution),
        type_=type_.substitute(substitution),
        loc~,
      )
    Handler(body~, handlers~, final_branch~, type_~, loc~) =>
      Handler(
        body=body.map(fn(body) { body.substitute(substitution) }),
        handlers=handlers.map(fn(handler) { handler.substitute(substitution) }),
        final_branch=final_branch.substitute(substitution),
        type_=type_.substitute(substitution),
        loc~,
      )
    Field(base~, field~, name~, type_~, loc~) =>
      Field(
        base=base.substitute(substitution),
        field~,
        name~,
        type_=type_.substitute(substitution),
        loc~,
      )
    StructLiteral(
      symbol~,
      generic_arguments~,
      type_witnesses~,
      fields~,
      type_~,
      loc~
    ) =>
      StructLiteral(
        symbol~,
        generic_arguments=generic_arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        type_witnesses=type_witnesses.map(fn(witness) {
          {
            symbol: witness.symbol,
            name: witness.name,
            type_: witness.type_.substitute(substitution),
            loc: witness.loc,
          }
        }),
        fields=fields.map(fn(field) { field.substitute(substitution) }),
        type_=type_.substitute(substitution),
        loc~,
      )
    Variant(symbol~, generic_arguments~, arguments~, type_~, loc~) =>
      Variant(
        symbol~,
        generic_arguments=generic_arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        arguments=arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        type_=type_.substitute(substitution),
        loc~,
      )
  }
}

///|
fn CheckedLocalItem::substitute(
  self : CheckedLocalItem,
  substitution : @types.TypeSubstitution,
) -> CheckedLocalItem {
  match self {
    Let(declaration) =>
      Let({
        is_public: declaration.is_public,
        symbol: declaration.symbol,
        name: declaration.name,
        initializer: declaration.initializer.substitute(substitution),
        type_: declaration.type_.substitute(substitution),
        loc: declaration.loc,
      })
    PatternLet(declaration) =>
      PatternLet({
        pattern: declaration.pattern.substitute(substitution),
        initializer: declaration.initializer.substitute(substitution),
        loc: declaration.loc,
      })
    Function(declaration) =>
      Function({
        is_public: declaration.is_public,
        symbol: declaration.symbol,
        name: declaration.name,
        type_parameters: declaration.type_parameters,
        parameters: substitute_value_parameters(
          declaration.parameters,
          substitution,
        ),
        return_type: declaration.return_type.substitute(substitution),
        body: declaration.body.substitute(substitution),
        type_: declaration.type_.substitute(substitution),
        loc: declaration.loc,
      })
  }
}

///|
fn substitute_value_parameters(
  parameters : Array[CheckedValueParameter],
  substitution : @types.TypeSubstitution,
) -> Array[CheckedValueParameter] {
  parameters.map(fn(parameter) {
    {
      symbol: parameter.symbol,
      is_auto: parameter.is_auto,
      is_offered: parameter.is_offered,
      name: parameter.name,
      type_: parameter.type_.substitute(substitution),
      loc: parameter.loc,
    }
  })
}

///|
fn CheckedCallArgument::substitute(
  self : CheckedCallArgument,
  substitution : @types.TypeSubstitution,
) -> CheckedCallArgument {
  { value: self.value.substitute(substitution), loc: self.loc }
}

///|
fn CheckedStructLiteralField::substitute(
  self : CheckedStructLiteralField,
  substitution : @types.TypeSubstitution,
) -> CheckedStructLiteralField {
  {
    symbol: self.symbol,
    name: self.name,
    value: self.value.substitute(substitution),
    loc: self.loc,
  }
}

///|
fn CheckedMatchArm::substitute(
  self : CheckedMatchArm,
  substitution : @types.TypeSubstitution,
) -> CheckedMatchArm {
  {
    pattern: self.pattern.substitute(substitution),
    body: self.body.substitute(substitution),
    loc: self.loc,
  }
}

///|
fn CheckedHandlerTable::substitute(
  self : CheckedHandlerTable,
  substitution : @types.TypeSubstitution,
) -> CheckedHandlerTable {
  {
    handled_effect: self.handled_effect.substitute(substitution),
    operations: self.operations.map(fn(operation) {
      operation.substitute(substitution)
    }),
    loc: self.loc,
  }
}

///|
fn CheckedHandlerOperationArm::substitute(
  self : CheckedHandlerOperationArm,
  substitution : @types.TypeSubstitution,
) -> CheckedHandlerOperationArm {
  {
    operation: self.operation,
    type_binders: self.type_binders,
    payload_types: self.payload_types.map(fn(type_) {
      type_.substitute(substitution)
    }),
    payload_patterns: self.payload_patterns.map(fn(pattern) {
      pattern.substitute(substitution)
    }),
    resume_symbol: self.resume_symbol,
    resume_type: self.resume_type.substitute(substitution),
    resume_binder: self.resume_binder,
    resume_loc: self.resume_loc,
    body: self.body.map(fn(body) { body.substitute(substitution) }),
    loc: self.loc,
  }
}

///|
fn CheckedHandlerFinalBranch::substitute(
  self : CheckedHandlerFinalBranch,
  substitution : @types.TypeSubstitution,
) -> CheckedHandlerFinalBranch {
  {
    binder_symbol: self.binder_symbol,
    binder: self.binder,
    binder_type: self.binder_type.substitute(substitution),
    binder_loc: self.binder_loc,
    body: self.body.map(fn(body) { body.substitute(substitution) }),
    loc: self.loc,
  }
}

///|
fn CheckedPattern::substitute(
  self : CheckedPattern,
  substitution : @types.TypeSubstitution,
) -> CheckedPattern {
  match self {
    Wildcard(type_~, loc~) =>
      Wildcard(type_=type_.substitute(substitution), loc~)
    Binding(name~, symbol~, type_~, loc~) =>
      Binding(name~, symbol~, type_=type_.substitute(substitution), loc~)
    Literal(literal~, type_~, loc~) =>
      Literal(literal~, type_=type_.substitute(substitution), loc~)
    Variant(symbol~, generic_arguments~, arguments~, type_~, loc~) =>
      Variant(
        symbol~,
        generic_arguments=generic_arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        arguments=arguments.map(fn(argument) {
          argument.substitute(substitution)
        }),
        type_=type_.substitute(substitution),
        loc~,
      )
    Struct(symbol~, type_binders~, fields~, type_~, loc~) =>
      Struct(
        symbol~,
        type_binders~,
        fields=fields.map(fn(field) { field.substitute(substitution) }),
        type_=type_.substitute(substitution),
        loc~,
      )
  }
}

///|
fn CheckedStructPatternField::substitute(
  self : CheckedStructPatternField,
  substitution : @types.TypeSubstitution,
) -> CheckedStructPatternField {
  {
    symbol: self.symbol,
    name: self.name,
    pattern: self.pattern.substitute(substitution),
    loc: self.loc,
  }
}
