///|
/// Desugars surface-only expression forms after name resolution.
pub fn desugar_source_file(
  source : @resolve.ResolvedSourceFile,
) -> DesugaredSourceFile {
  let declarations = []
  for declaration in source.declarations {
    if desugar_top_level_declaration(declaration) is Some(declaration) {
      declarations.push(declaration)
    }
  }
  {
    module_path: source.module_path,
    symbols: source.symbols,
    declarations,
    loc: source.loc,
  }
}

///|
fn desugar_top_level_declaration(
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> DesugaredTopLevelDeclaration? {
  match declaration {
    Struct(declaration) => Some(Struct(declaration))
    Enum(declaration) => Some(Enum(declaration))
    Effect(declaration) => Some(Effect(declaration))
    ExternalType(declaration) => Some(ExternalType(declaration))
    TypeAlias(_) => None
    Function(declaration) =>
      Some(Function(desugar_function_declaration(declaration)))
    Let(declaration) => Some(Let(desugar_let_declaration(declaration)))
  }
}

///|
fn desugar_function_declaration(
  declaration : @resolve.ResolvedFunctionDeclaration,
) -> DesugaredFunctionDeclaration {
  {
    is_public: declaration.is_public,
    is_offered: declaration.is_offered,
    symbol: declaration.symbol,
    name: declaration.name,
    name_loc: declaration.name_loc,
    type_parameters: declaration.type_parameters,
    parameters: declaration.parameters,
    return_type: declaration.return_type,
    effect: declaration.effect,
    body: desugar_expr(declaration.body),
    loc: declaration.loc,
  }
}

///|
fn desugar_let_declaration(
  declaration : @resolve.ResolvedLetDeclaration,
) -> DesugaredLetDeclaration {
  {
    is_public: declaration.is_public,
    is_offered: declaration.is_offered,
    symbol: declaration.symbol,
    name: declaration.name,
    name_loc: declaration.name_loc,
    type_annotation: declaration.type_annotation,
    initializer: desugar_expr(declaration.initializer),
    loc: declaration.loc,
  }
}

///|
fn desugar_local_item(item : @resolve.ResolvedLocalItem) -> DesugaredLocalItem? {
  match item {
    Let(declaration) => Some(Let(desugar_let_declaration(declaration)))
    PatternLet(declaration) =>
      Some(PatternLet(desugar_pattern_let_declaration(declaration)))
    Function(declaration) =>
      Some(Function(desugar_function_declaration(declaration)))
    Expression(expression) => Some(Expression(desugar_expr(expression)))
  }
}

///|
fn desugar_pattern_let_declaration(
  declaration : @resolve.ResolvedPatternLetDeclaration,
) -> DesugaredPatternLetDeclaration {
  {
    pattern: declaration.pattern,
    type_annotation: declaration.type_annotation,
    initializer: desugar_expr(declaration.initializer),
    loc: declaration.loc,
  }
}

///|
fn desugar_struct_literal_field(
  field : @resolve.ResolvedStructLiteralField,
) -> DesugaredStructLiteralField {
  match field {
    Value(name~, value~, punned_reference~, loc~) => {
      let value = match value {
        Some(value) => desugar_expr(value)
        None =>
          match punned_reference {
            Some(reference) => Var(name~, reference~, loc~)
            None => Var(name~, reference=Unresolved(name), loc~)
          }
      }
      Value(name~, value~, loc~)
    }
    TypeWitness(name~, witness~, loc~) => TypeWitness(name~, witness~, loc~)
  }
}

///|
fn desugar_match_arm(arm : @resolve.ResolvedMatchArm) -> DesugaredMatchArm {
  { pattern: arm.pattern, body: desugar_expr(arm.body), loc: arm.loc }
}

///|
fn desugar_handler_with_block(
  handler : @resolve.ResolvedHandlerWithBlock,
) -> DesugaredHandlerWithBlock {
  { arms: handler.arms.map(desugar_handler_operation_arm), loc: handler.loc }
}

///|
fn desugar_handler_operation_arm(
  arm : @resolve.ResolvedHandlerOperationArm,
) -> DesugaredHandlerOperationArm {
  {
    name: arm.name,
    type_binders: arm.type_binders,
    payload_patterns: arm.payload_patterns,
    resume_symbol: arm.resume_symbol,
    resume_binder: arm.resume_binder,
    resume_loc: arm.resume_loc,
    body: desugar_expr(arm.body),
    loc: arm.loc,
  }
}

///|
fn desugar_handler_final_branch(
  branch : @resolve.ResolvedHandlerFinalBranch,
) -> DesugaredHandlerFinalBranch {
  {
    binder_symbol: branch.binder_symbol,
    binder: branch.binder,
    binder_loc: branch.binder_loc,
    body: desugar_expr(branch.body),
    loc: branch.loc,
  }
}

///|
fn desugar_expr(expr : @resolve.ResolvedExpr) -> DesugaredExpr {
  match expr {
    IntLiteral(value, loc~) => Literal(literal=Int(value), loc~)
    DoubleLiteral(value, loc~) => Literal(literal=Double(value), loc~)
    StringLiteral(value, loc~) => Literal(literal=String(value), loc~)
    BoolLiteral(value, loc~) => Literal(literal=Bool(value), loc~)
    UnitLiteral(loc~) => Literal(literal=Unit, loc~)
    Var(name~, reference~, loc~) => Var(name~, reference~, loc~)
    QualifiedVariant(
      type_name~,
      type_name_loc~,
      generic_arguments~,
      variant~,
      variant_loc~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      VariantCall(
        type_name=Some(type_name),
        type_name_loc=Some(type_name_loc),
        generic_arguments~,
        variant~,
        variant_loc~,
        variant_generic_arguments~,
        reference~,
        arguments=arguments.map(desugar_expr),
        loc~,
      )
    UnqualifiedVariant(
      variant~,
      variant_loc~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      VariantCall(
        type_name=None,
        type_name_loc=None,
        generic_arguments=[],
        variant~,
        variant_loc~,
        variant_generic_arguments~,
        reference~,
        arguments=arguments.map(desugar_expr),
        loc~,
      )
    StructLiteral(
      type_name~,
      type_name_loc~,
      reference~,
      generic_arguments~,
      fields~,
      loc~
    ) =>
      StructLiteral(
        type_name~,
        type_name_loc~,
        reference~,
        generic_arguments~,
        fields=desugar_struct_literal_fields(fields),
        loc~,
      )
    ListLiteral(items~, empty_reference~, cons_reference~, loc~) =>
      desugar_list_literal(items, empty_reference, cons_reference, loc)
    Builtin(name, loc~) => Builtin(name, loc~)
    Extern(name, loc~) => Extern(name, loc~)
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      FunctionLiteral(
        type_parameters~,
        parameters~,
        return_type~,
        effect~,
        body=desugar_expr(body),
        loc~,
      )
    EffectOperationCall(name~, generic_witnesses~, arguments~, loc~) =>
      EffectOperationCall(
        name~,
        generic_witnesses~,
        arguments=arguments.map(desugar_expr),
        loc~,
      )
    GenericApplication(callee~, arguments~, loc~) =>
      GenericApplication(callee=desugar_expr(callee), arguments~, loc~)
    Handler(body~, handlers~, final_branch~, loc~) =>
      Handler(
        body=desugar_expr(body),
        handlers=handlers.map(desugar_handler_with_block),
        final_branch=desugar_handler_final_branch(final_branch),
        loc~,
      )
    Block(items~, result~, loc~) =>
      Block(items=desugar_local_items(items), result=desugar_expr(result), loc~)
    If(condition~, then_branch~, else_branch~, loc~) =>
      If(
        condition=desugar_expr(condition),
        then_branch=desugar_expr(then_branch),
        else_branch=desugar_expr(else_branch),
        loc~,
      )
    Match(scrutinee~, arms~, loc~) =>
      Match(
        scrutinee=desugar_expr(scrutinee),
        arms=arms.map(desugar_match_arm),
        loc~,
      )
    Call(callee~, arguments~, loc~) =>
      Call(
        callee=desugar_expr(callee),
        arguments=arguments.map(desugar_call_argument),
        loc~,
      )
    Field(base~, name~, name_loc~, reference~, loc~) =>
      Field(base=desugar_expr(base), name~, name_loc~, reference~, loc~)
    Unary(operator~, reference~, operand~, loc~) =>
      desugar_operator_call(
        operator.operation_name(),
        reference,
        [desugar_expr(operand)],
        loc,
      )
    Binary(operator~, reference~, left~, right~, loc~) =>
      if operator.is_lazy_bool_operator() {
        desugar_operator_call(
          operator.operation_name(),
          reference,
          [desugar_expr(left), desugar_bool_thunk(right, loc)],
          loc,
        )
      } else {
        desugar_operator_call(
          operator.operation_name(),
          reference,
          [desugar_expr(left), desugar_expr(right)],
          loc,
        )
      }
    Pipeline(left~, right~, loc~) =>
      desugar_pipeline(desugar_expr(left), desugar_expr(right), loc)
  }
}

///|
fn desugar_list_literal(
  items : Array[@resolve.ResolvedExpr],
  empty_reference : @resolve.ResolvedVariantReference,
  cons_reference : @resolve.ResolvedVariantReference?,
  loc : @basic.SourceSpan,
) -> DesugaredExpr {
  let mut result = VariantCall(
    type_name=None,
    type_name_loc=None,
    generic_arguments=[],
    variant="empty",
    variant_loc=loc,
    variant_generic_arguments=[],
    reference=empty_reference,
    arguments=[],
    loc~,
  )
  guard cons_reference is Some(cons_reference) else { return result }
  for index = items.length() - 1; index >= 0; index = index - 1 {
    result = VariantCall(
      type_name=None,
      type_name_loc=None,
      generic_arguments=[],
      variant="cons",
      variant_loc=loc,
      variant_generic_arguments=[],
      reference=cons_reference,
      arguments=[desugar_expr(items[index]), result],
      loc~,
    )
  }
  result
}

///|
fn desugar_struct_literal_fields(
  fields : Array[@resolve.ResolvedStructLiteralField],
) -> Array[DesugaredStructLiteralField] {
  fields.map(desugar_struct_literal_field)
}

///|
fn desugar_local_items(
  items : Array[@resolve.ResolvedLocalItem],
) -> Array[DesugaredLocalItem] {
  let result = []
  for item in items {
    if desugar_local_item(item) is Some(item) {
      result.push(item)
    }
  }
  result
}

///|
fn desugar_operator_call(
  name : String,
  reference : @resolve.ResolvedValueReference,
  arguments : Array[DesugaredExpr],
  loc : SourceSpan,
) -> DesugaredExpr {
  Call(
    callee=Var(name~, reference~, loc~),
    arguments=arguments.map(fn(argument) {
      Positional(value=argument, loc=argument.loc())
    }),
    loc~,
  )
}

///|
fn desugar_pipeline(
  left : DesugaredExpr,
  right : DesugaredExpr,
  loc : SourceSpan,
) -> DesugaredExpr {
  if right is Call(callee~, arguments~, ..) {
    Call(
      callee~,
      arguments=prepend_argument(
        Positional(value=left, loc=left.loc()),
        arguments,
      ),
      loc~,
    )
  } else {
    Call(callee=right, arguments=[Positional(value=left, loc=left.loc())], loc~)
  }
}

///|
fn prepend_argument(
  first : DesugaredCallArgument,
  rest : Array[DesugaredCallArgument],
) -> Array[DesugaredCallArgument] {
  let result = [first]
  for argument in rest {
    result.push(argument)
  }
  result
}

///|
fn desugar_call_argument(
  argument : @resolve.ResolvedCallArgument,
) -> DesugaredCallArgument {
  match argument {
    Positional(value~, loc~) => Positional(value=desugar_expr(value), loc~)
    Named(name~, value~, loc~) => Named(name~, value=desugar_expr(value), loc~)
  }
}

///|
fn desugar_bool_thunk(
  body : @resolve.ResolvedExpr,
  loc : SourceSpan,
) -> DesugaredExpr {
  FunctionLiteral(
    type_parameters=[],
    parameters=[],
    return_type=Some(Primitive(Bool, loc~)),
    effect=None,
    body=desugar_expr(body),
    loc~,
  )
}

///|
fn @syntax.UnaryOperator::operation_name(
  self : @syntax.UnaryOperator,
) -> String {
  match self {
    Neg => "op_neg"
    Not => "op_not"
  }
}

///|
fn @syntax.BinaryOperator::operation_name(
  self : @syntax.BinaryOperator,
) -> String {
  match self {
    Add => "op_add"
    Sub => "op_sub"
    Mul => "op_mul"
    Div => "op_div"
    Rem => "op_rem"
    Equal => "op_equal"
    NotEqual => "op_not_equal"
    Less => "op_less"
    LessEqual => "op_less_eq"
    Greater => "op_greater"
    GreaterEqual => "op_greater_eq"
    And => "op_and"
    Or => "op_or"
  }
}

///|
fn @syntax.BinaryOperator::is_lazy_bool_operator(
  self : @syntax.BinaryOperator,
) -> Bool {
  self is (And | Or)
}
