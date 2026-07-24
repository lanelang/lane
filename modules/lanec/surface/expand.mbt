///|
pub(all) enum SurfaceGeneratedReference {
  Type(name~ : String, loc~ : @basic.SourceSpan)
  Variant(type_name~ : String, variant~ : String, loc~ : @basic.SourceSpan)
} derive(Debug, Eq)

///|
pub(all) struct SurfaceExpansion {
  source : @syntax.SourceFile
  generated_references : Array[SurfaceGeneratedReference]
} derive(Debug, Eq)

///|
priv struct SurfaceExpander {
  generated_references : Array[SurfaceGeneratedReference]
}

///|
pub fn expand_source(source : @syntax.SourceFile) -> SurfaceExpansion {
  let expander : SurfaceExpander = { generated_references: [] }
  {
    source: expander.expand_source(source),
    generated_references: expander.generated_references,
  }
}

///|
fn SurfaceExpander::expand_source(
  self : SurfaceExpander,
  source : @syntax.SourceFile,
) -> @syntax.SourceFile {
  {
    ..source,
    declarations: source.declarations.map(fn(declaration) {
      self.expand_declaration(declaration)
    }),
  }
}

///|
fn SurfaceExpander::expand_declaration(
  self : SurfaceExpander,
  declaration : @syntax.TopLevelDeclaration,
) -> @syntax.TopLevelDeclaration {
  match declaration {
    Struct(declaration) =>
      Struct({
        ..declaration,
        members: declaration.members.map(fn(declaration_member) {
          match declaration_member {
            TypeMember(_) => declaration_member
            Field(field) =>
              Field({ ..field, type_: self.expand_type(field.type_) })
          }
        }),
      })
    Enum(declaration) =>
      Enum({
        ..declaration,
        variants: declaration.variants.map(fn(variant) {
          {
            ..variant,
            payload: variant.payload.map(fn(type_) { self.expand_type(type_) }),
          }
        }),
      })
    Effect(declaration) =>
      Effect({
        ..declaration,
        operations: declaration.operations.map(fn(operation) {
          {
            ..operation,
            payload: operation.payload.map(fn(type_) { self.expand_type(type_) }),
            result: self.expand_type(operation.result),
          }
        }),
      })
    ExternalType(_) => declaration
    TypeAlias(declaration) =>
      TypeAlias({
        ..declaration,
        body: match declaration.body {
          TypeBody(type_) => TypeBody(self.expand_type(type_))
          EffectBody(effect) => EffectBody(self.expand_effect(effect))
        },
      })
    Function(declaration) =>
      Function(self.expand_function_declaration(declaration))
    Let(declaration) => Let(self.expand_let_declaration(declaration))
  }
}

///|
fn SurfaceExpander::expand_function_declaration(
  self : SurfaceExpander,
  declaration : @syntax.FunctionDeclaration,
) -> @syntax.FunctionDeclaration {
  {
    ..declaration,
    parameters: declaration.parameters.map(fn(parameter) {
      { ..parameter, type_: self.expand_type(parameter.type_) }
    }),
    return_type: self.expand_type(declaration.return_type),
    effect: self.expand_effect(declaration.effect),
    body: self.expand_expression(declaration.body),
  }
}

///|
fn SurfaceExpander::expand_let_declaration(
  self : SurfaceExpander,
  declaration : @syntax.LetDeclaration,
) -> @syntax.LetDeclaration {
  {
    ..declaration,
    type_annotation: declaration.type_annotation.map(fn(type_) {
      self.expand_type(type_)
    }),
    initializer: self.expand_expression(declaration.initializer),
  }
}

///|
fn tuple_qualified_type(loc : @basic.SourceSpan) -> @syntax.Type {
  QualifiedName(
    module_path={ components: ["Basic", "Data", "Tuple"], loc },
    name="Tuple",
    loc~,
  )
}

///|
fn list_qualified_type(loc : @basic.SourceSpan) -> @syntax.Type {
  QualifiedName(
    module_path={ components: ["Basic", "Data", "List"], loc },
    name="List",
    loc~,
  )
}

///|
fn[T, U] expand_right_nested(
  items : Array[T],
  expand_item : (T) -> U,
  combine : (U, U) -> U,
) -> U {
  guard items.length() >= 2 else {
    abort("tuple sugar must contain at least two items")
  }
  let expanded = items.map(expand_item)
  let mut result = expanded[expanded.length() - 1]
  for index = expanded.length() - 2; index >= 0; index = index - 1 {
    result = combine(expanded[index], result)
  }
  result
}

///|
fn SurfaceExpander::expand_type(
  self : SurfaceExpander,
  type_ : @syntax.Type,
) -> @syntax.Type {
  match type_ {
    Name(_) | QualifiedName(_) => type_
    Apply(callee~, arguments~, loc~) =>
      Apply(
        callee=self.expand_type(callee),
        arguments=arguments.map(fn(argument) {
          self.expand_generic_argument(argument)
        }),
        loc~,
      )
    TypeLambda(parameters~, body~, loc~) =>
      TypeLambda(parameters~, body=self.expand_type(body), loc~)
    Function(type_parameters~, parameters~, result~, effect~, loc~) =>
      Function(
        type_parameters~,
        parameters=parameters.map(fn(parameter) { self.expand_type(parameter) }),
        result=self.expand_type(result),
        effect=self.expand_effect(effect),
        loc~,
      )
    Tuple(items~, loc~) => {
      self.generated_references.push(Type(name="Basic.Data.Tuple.Tuple", loc~))
      expand_right_nested(items, fn(item) { self.expand_type(item) }, fn(
        left,
        right,
      ) {
        Apply(
          callee=tuple_qualified_type(loc),
          arguments=[TypeTerm(left), TypeTerm(right)],
          loc~,
        )
      })
    }
    Grouped(type_~, loc~) => Grouped(type_=self.expand_type(type_), loc~)
  }
}

///|
fn SurfaceExpander::expand_effect(
  self : SurfaceExpander,
  effect : @syntax.EffectTerm,
) -> @syntax.EffectTerm {
  match effect {
    Empty(_) => effect
    Term(type_~, loc~) => Term(type_=self.expand_type(type_), loc~)
    Union(items~, loc~) =>
      Union(items=items.map(fn(item) { self.expand_type(item) }), loc~)
  }
}

///|
fn SurfaceExpander::expand_generic_argument(
  self : SurfaceExpander,
  argument : @syntax.GenericArgument,
) -> @syntax.GenericArgument {
  match argument {
    TypeTerm(type_) => TypeTerm(self.expand_type(type_))
    EffectTerm(effect) => EffectTerm(self.expand_effect(effect))
  }
}

///|
fn SurfaceExpander::expand_list_expression(
  self : SurfaceExpander,
  items : Array[@syntax.Expr],
  index : Int,
  loc : @basic.SourceSpan,
) -> @syntax.Expr {
  if index == items.length() {
    return QualifiedVariant(
      owner=list_qualified_type(loc),
      variant="empty",
      variant_loc=loc,
      variant_type_arguments=[],
      arguments=[],
      loc~,
    )
  }
  QualifiedVariant(
    owner=list_qualified_type(loc),
    variant="cons",
    variant_loc=loc,
    variant_type_arguments=[],
    arguments=[
      self.expand_expression(items[index]),
      self.expand_list_expression(items, index + 1, loc),
    ],
    loc~,
  )
}

///|
fn SurfaceExpander::expand_expression(
  self : SurfaceExpander,
  expression : @syntax.Expr,
) -> @syntax.Expr {
  match expression {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_)
    | Extern(_) => expression
    QualifiedVariant(
      owner~,
      variant~,
      variant_loc~,
      variant_type_arguments~,
      arguments~,
      loc~
    ) =>
      QualifiedVariant(
        owner=self.expand_type(owner),
        variant~,
        variant_loc~,
        variant_type_arguments=variant_type_arguments.map(fn(argument) {
          self.expand_generic_argument(argument)
        }),
        arguments=arguments.map(fn(argument) {
          self.expand_expression(argument)
        }),
        loc~,
      )
    StructLiteral(owner~, fields~, loc~) =>
      StructLiteral(
        owner=self.expand_type(owner),
        fields=fields.map(fn(field) {
          match field {
            Value(name~, value~, loc~) =>
              Value(
                name~,
                value=value.map(fn(value) { self.expand_expression(value) }),
                loc~,
              )
            TypeWitness(name~, witness~, loc~) =>
              TypeWitness(name~, witness=self.expand_type(witness), loc~)
          }
        }),
        loc~,
      )
    ListLiteral(items~, loc~) => {
      if !items.is_empty() {
        self.generated_references.push(
          Variant(type_name="Basic.Data.List.List", variant="cons", loc~),
        )
      }
      self.generated_references.push(
        Variant(type_name="Basic.Data.List.List", variant="empty", loc~),
      )
      self.expand_list_expression(items, 0, loc)
    }
    TupleLiteral(items~, loc~) => {
      self.generated_references.push(
        Variant(type_name="Basic.Data.Tuple.Tuple", variant="tuple", loc~),
      )
      expand_right_nested(items, fn(item) { self.expand_expression(item) }, fn(
        left,
        right,
      ) {
        QualifiedVariant(
          owner=tuple_qualified_type(loc),
          variant="tuple",
          variant_loc=loc,
          variant_type_arguments=[],
          arguments=[left, right],
          loc~,
        )
      })
    }
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
        parameters=parameters.map(fn(parameter) {
          {
            ..parameter,
            type_annotation: parameter.type_annotation.map(fn(type_) {
              self.expand_type(type_)
            }),
          }
        }),
        return_type=return_type.map(fn(type_) { self.expand_type(type_) }),
        effect=effect.map(fn(effect) { self.expand_effect(effect) }),
        body=self.expand_expression(body),
        loc~,
      )
    EffectOperationCall(name~, type_witnesses~, arguments~, loc~) =>
      EffectOperationCall(
        name=self.expand_effect_operation_name(name),
        type_witnesses=type_witnesses.map(fn(argument) {
          self.expand_generic_argument(argument)
        }),
        arguments=arguments.map(fn(argument) {
          self.expand_expression(argument)
        }),
        loc~,
      )
    TypeApplication(callee~, arguments~, loc~) =>
      TypeApplication(
        callee=self.expand_expression(callee),
        arguments=arguments.map(fn(argument) {
          self.expand_generic_argument(argument)
        }),
        loc~,
      )
    Handler(body~, handlers~, final_branch~, loc~) =>
      Handler(
        body=self.expand_expression(body),
        handlers=handlers.map(fn(handler) {
          {
            ..handler,
            arms: handler.arms.map(fn(arm) {
              {
                ..arm,
                name: self.expand_effect_operation_name(arm.name),
                payload_patterns: arm.payload_patterns.map(fn(pattern) {
                  self.expand_pattern(pattern)
                }),
                body: self.expand_expression(arm.body),
              }
            }),
          }
        }),
        final_branch={
          ..final_branch,
          body: self.expand_expression(final_branch.body),
        },
        loc~,
      )
    Block(items~, result~, loc~) =>
      Block(
        items=items.map(fn(item) { self.expand_local_item(item) }),
        result=self.expand_expression(result),
        loc~,
      )
    If(condition~, then_branch~, else_branch~, loc~) =>
      If(
        condition=self.expand_expression(condition),
        then_branch=self.expand_expression(then_branch),
        else_branch=else_branch.map(fn(branch) {
          self.expand_expression(branch)
        }),
        loc~,
      )
    Match(scrutinee~, arms~, loc~) =>
      Match(
        scrutinee=self.expand_expression(scrutinee),
        arms=arms.map(fn(arm) {
          {
            ..arm,
            pattern: self.expand_pattern(arm.pattern),
            body: self.expand_expression(arm.body),
          }
        }),
        loc~,
      )
    Call(callee~, arguments~, loc~) =>
      Call(
        callee=self.expand_expression(callee),
        arguments=arguments.map(fn(argument) {
          match argument {
            Positional(value~, loc~) =>
              Positional(value=self.expand_expression(value), loc~)
            Named(name~, value~, loc~) =>
              Named(name~, value=self.expand_expression(value), loc~)
          }
        }),
        loc~,
      )
    Field(base~, name~, name_loc~, loc~) =>
      Field(base=self.expand_expression(base), name~, name_loc~, loc~)
    Unary(operator~, operand~, loc~) =>
      Unary(operator~, operand=self.expand_expression(operand), loc~)
    Binary(operator~, left~, right~, loc~) =>
      Binary(
        operator~,
        left=self.expand_expression(left),
        right=self.expand_expression(right),
        loc~,
      )
    Pipeline(left~, right~, loc~) =>
      Pipeline(
        left=self.expand_expression(left),
        right=self.expand_expression(right),
        loc~,
      )
    Grouped(expression~, loc~) =>
      Grouped(expression=self.expand_expression(expression), loc~)
  }
}

///|
fn SurfaceExpander::expand_effect_operation_name(
  self : SurfaceExpander,
  name : @syntax.EffectOperationName,
) -> @syntax.EffectOperationName {
  match name {
    Qualified(owner~, operation~, operation_loc~) =>
      Qualified(owner=self.expand_type(owner), operation~, operation_loc~)
    Unqualified(_) => name
  }
}

///|
fn SurfaceExpander::expand_local_item(
  self : SurfaceExpander,
  item : @syntax.LocalItem,
) -> @syntax.LocalItem {
  match item {
    Let(declaration) => Let(self.expand_let_declaration(declaration))
    PatternLet(declaration) =>
      PatternLet({
        ..declaration,
        pattern: self.expand_pattern(declaration.pattern),
        type_annotation: declaration.type_annotation.map(fn(type_) {
          self.expand_type(type_)
        }),
        initializer: self.expand_expression(declaration.initializer),
      })
    Function(declaration) =>
      Function(self.expand_function_declaration(declaration))
    Expression(expression~) =>
      Expression(expression=self.expand_expression(expression))
  }
}

///|
fn tuple_pattern_type_name() -> String {
  "Basic.Data.Tuple.Tuple"
}

///|
fn SurfaceExpander::expand_pattern(
  self : SurfaceExpander,
  pattern : @syntax.Pattern,
) -> @syntax.Pattern {
  match pattern {
    Wildcard(_)
    | Binding(_)
    | IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_) => pattern
    QualifiedVariant(
      type_name~,
      type_name_loc~,
      variant~,
      variant_loc~,
      type_binders~,
      arguments~,
      loc~
    ) =>
      QualifiedVariant(
        type_name~,
        type_name_loc~,
        variant~,
        variant_loc~,
        type_binders~,
        arguments=arguments.map(fn(pattern) { self.expand_pattern(pattern) }),
        loc~,
      )
    UnqualifiedVariant(variant~, variant_loc~, type_binders~, arguments~, loc~) =>
      UnqualifiedVariant(
        variant~,
        variant_loc~,
        type_binders~,
        arguments=arguments.map(fn(pattern) { self.expand_pattern(pattern) }),
        loc~,
      )
    Struct(type_name~, type_name_loc~, fields~, loc~) =>
      Struct(
        type_name~,
        type_name_loc~,
        fields=fields.map(fn(field) {
          match field {
            Value(name~, pattern~, loc~) =>
              Value(
                name~,
                pattern=pattern.map(fn(pattern) { self.expand_pattern(pattern) }),
                loc~,
              )
            TypeBinder(_) | TypeWildcard(_) => field
          }
        }),
        loc~,
      )
    Tuple(items~, loc~) => {
      self.generated_references.push(
        Variant(type_name="Basic.Data.Tuple.Tuple", variant="tuple", loc~),
      )
      expand_right_nested(items, fn(item) { self.expand_pattern(item) }, fn(
        left,
        right,
      ) {
        QualifiedVariant(
          type_name=tuple_pattern_type_name(),
          type_name_loc=loc,
          variant="tuple",
          variant_loc=loc,
          type_binders=[],
          arguments=[left, right],
          loc~,
        )
      })
    }
  }
}
