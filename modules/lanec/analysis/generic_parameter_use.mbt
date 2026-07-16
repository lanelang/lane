///|
priv enum GenericParameterUseKind {
  GenericTypeParameter
  GenericEffectParameter
}

///|
priv struct GenericParameterUseBinder {
  symbol : @symbol.TypeParameterId
  name : String
  kind : GenericParameterUseKind
  loc : @basic.SourceSpan
}

///|
priv struct GenericParameterUseAnalysis {
  binders : Array[GenericParameterUseBinder]
  references : Array[@symbol.TypeParameterId]
}

///|
priv struct GenericParameterUseCollector {
  binders : Array[GenericParameterUseBinder]
  references : Array[@symbol.TypeParameterId]
}

///|
fn @resolve.ResolvedSourceFile::generic_parameter_use_analysis(
  self : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
) -> GenericParameterUseAnalysis {
  let collector = GenericParameterUseCollector::{ binders: [], references: [] }
  for declaration in self.declarations {
    collector.collect_declaration(declaration)
  }
  collector.collect_checked_source(checked)
  { binders: collector.binders, references: collector.references }
}

///|
fn GenericParameterUseAnalysis::unused_binders(
  self : GenericParameterUseAnalysis,
) -> Array[GenericParameterUseBinder] {
  let unused = []
  for binder in self.binders {
    if !binder.name.has_prefix("_") && !self.references.contains(binder.symbol) {
      unused.push(binder)
    }
  }
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn GenericParameterUseCollector::collect_declaration(
  self : GenericParameterUseCollector,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      self.add_parameters(declaration.type_parameters)
      for struct_member in declaration.members {
        self.collect_struct_member(struct_member)
      }
    }
    Enum(declaration) => {
      self.add_parameters(declaration.type_parameters)
      for variant in declaration.variants {
        self.add_parameters(variant.type_parameters)
        for payload in variant.payload {
          self.collect_type(payload)
        }
      }
    }
    Effect(declaration) =>
      if declaration.flavor is Algebraic {
        self.add_parameters(declaration.type_parameters)
        for operation in declaration.operations {
          self.add_parameters(operation.type_parameters)
          for payload in operation.payload {
            self.collect_type(payload)
          }
          self.collect_type(operation.result)
        }
      }
    ExternalType(declaration) =>
      self.add_parameters(declaration.type_parameters)
    TypeAlias(declaration) => {
      self.add_parameters(declaration.type_parameters)
      match declaration.body {
        TypeBody(type_) => self.collect_type(type_)
        EffectBody(effect) => self.collect_effect(effect)
      }
    }
    Function(declaration) => {
      self.add_parameters(declaration.type_parameters)
      for parameter in declaration.parameters {
        self.collect_type(parameter.type_)
      }
      self.collect_type(declaration.return_type)
      self.collect_effect(declaration.effect)
      self.collect_expr(declaration.body)
    }
    Let(declaration) => {
      if declaration.type_annotation is Some(type_) {
        self.collect_type(type_)
      }
      self.collect_expr(declaration.initializer)
    }
    Offer(declaration) => {
      self.collect_type(declaration.type_annotation)
      self.collect_expr(declaration.initializer)
    }
  }
}

///|
fn GenericParameterUseCollector::add_parameters(
  self : GenericParameterUseCollector,
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Unit {
  for parameter in parameters {
    self.binders.push({
      symbol: parameter.symbol,
      name: parameter.name,
      kind: resolved_type_parameter_use_kind(parameter),
      loc: parameter.loc,
    })
  }
}

///|
fn resolved_type_parameter_use_kind(
  parameter : @resolve.ResolvedTypeParameter,
) -> GenericParameterUseKind {
  match parameter.kind {
    Some(Effect(_)) => GenericEffectParameter
    _ => GenericTypeParameter
  }
}

///|
fn GenericParameterUseCollector::collect_struct_member(
  self : GenericParameterUseCollector,
  struct_member : @resolve.ResolvedStructMember,
) -> Unit {
  match struct_member {
    TypeMember(_) => ()
    Field(field) => self.collect_type(field.type_)
  }
}

///|
fn GenericParameterUseCollector::collect_local_item(
  self : GenericParameterUseCollector,
  item : @resolve.ResolvedLocalItem,
) -> Unit {
  match item {
    Let(declaration) => {
      if declaration.type_annotation is Some(type_) {
        self.collect_type(type_)
      }
      self.collect_expr(declaration.initializer)
    }
    PatternLet(declaration) => {
      if declaration.type_annotation is Some(type_) {
        self.collect_type(type_)
      }
      self.collect_expr(declaration.initializer)
      self.collect_pattern(declaration.pattern)
    }
    Function(declaration) => {
      self.add_parameters(declaration.type_parameters)
      for parameter in declaration.parameters {
        self.collect_type(parameter.type_)
      }
      self.collect_type(declaration.return_type)
      self.collect_effect(declaration.effect)
      self.collect_expr(declaration.body)
    }
    Offer(declaration) => {
      self.collect_type(declaration.type_annotation)
      self.collect_expr(declaration.initializer)
    }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_source(
  self : GenericParameterUseCollector,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        for field in declaration.fields {
          self.collect_checked_type(field.type_)
        }
      Enum(declaration) =>
        for variant in declaration.variants {
          for payload in variant.payload {
            self.collect_checked_type(payload)
          }
        }
      Effect(declaration) =>
        for operation in declaration.operations {
          for payload in operation.payload {
            self.collect_checked_type(payload)
          }
          self.collect_checked_type(operation.result)
        }
      ExternalType(_) => ()
      Function(declaration) => {
        for parameter in declaration.parameters {
          self.collect_checked_type(parameter.type_)
        }
        self.collect_checked_type(declaration.return_type)
        self.collect_checked_expr(declaration.body)
      }
      Let(declaration) => {
        self.collect_checked_type(declaration.type_)
        self.collect_checked_expr(declaration.initializer)
      }
    }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_local_item(
  self : GenericParameterUseCollector,
  item : @checked.CheckedLocalItem,
) -> Unit {
  match item {
    Let(declaration) => {
      self.collect_checked_type(declaration.type_)
      self.collect_checked_expr(declaration.initializer)
    }
    PatternLet(declaration) => {
      self.collect_checked_expr(declaration.initializer)
      self.collect_checked_pattern(declaration.pattern)
    }
    Function(declaration) => {
      for parameter in declaration.parameters {
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(declaration.return_type)
      self.collect_checked_expr(declaration.body)
    }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_expr(
  self : GenericParameterUseCollector,
  expr : @checked.CheckedExpr,
) -> Unit {
  match expr {
    Literal(type_~, ..)
    | Value(type_~, ..)
    | CompilerIntrinsic(type_~, ..)
    | ExternBinding(type_~, ..) => self.collect_checked_type(type_)
    FunctionLiteral(parameters~, return_type~, body~, type_~, ..) => {
      for parameter in parameters {
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(return_type)
      self.collect_checked_type(type_)
      self.collect_checked_expr(body)
    }
    GenericApplication(callee~, arguments~, type_~, ..) => {
      self.collect_checked_expr(callee)
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
    Block(items~, result~, type_~, ..) => {
      for item in items {
        self.collect_checked_local_item(item)
      }
      self.collect_checked_expr(result)
      self.collect_checked_type(type_)
    }
    If(condition~, then_branch~, else_branch~, type_~, ..) => {
      self.collect_checked_expr(condition)
      self.collect_checked_expr(then_branch)
      self.collect_checked_expr(else_branch)
      self.collect_checked_type(type_)
    }
    Match(scrutinee~, arms~, type_~, ..) => {
      self.collect_checked_expr(scrutinee)
      for arm in arms {
        self.collect_checked_pattern(arm.pattern)
        self.collect_checked_expr(arm.body)
      }
      self.collect_checked_type(type_)
    }
    Call(callee~, arguments~, type_~, ..) => {
      self.collect_checked_expr(callee)
      for argument in arguments {
        self.collect_checked_expr(argument.value)
      }
      self.collect_checked_type(type_)
    }
    OperationCall(generic_witnesses~, arguments~, effect~, type_~, ..) => {
      for witness in generic_witnesses {
        self.collect_checked_generic_argument(witness)
      }
      for argument in arguments {
        self.collect_checked_expr(argument)
      }
      self.collect_checked_effect(effect)
      self.collect_checked_type(type_)
    }
    Handler(body~, handlers~, final_branch~, type_~, ..) => {
      if body is Some(body) {
        self.collect_checked_expr(body)
      }
      for handler in handlers {
        self.collect_checked_effect(handler.handled_effect)
        for arm in handler.operations {
          for payload_type in arm.payload_types {
            self.collect_checked_type(payload_type)
          }
          for pattern in arm.payload_patterns {
            self.collect_checked_pattern(pattern)
          }
          self.collect_checked_type(arm.resume_type)
          if arm.body is Some(body) {
            self.collect_checked_expr(body)
          }
        }
      }
      if final_branch.body is Some(body) {
        self.collect_checked_expr(body)
      }
      self.collect_checked_type(type_)
    }
    Field(base~, type_~, ..) => {
      self.collect_checked_expr(base)
      self.collect_checked_type(type_)
    }
    StructLiteral(generic_arguments~, type_witnesses~, fields~, type_~, ..) => {
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for witness in type_witnesses {
        self.collect_checked_type(witness.type_)
      }
      for field in fields {
        self.collect_checked_expr(field.value)
      }
      self.collect_checked_type(type_)
    }
    Variant(generic_arguments~, arguments~, type_~, ..) => {
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_checked_expr(argument)
      }
      self.collect_checked_type(type_)
    }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_pattern(
  self : GenericParameterUseCollector,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(type_~, ..) | Binding(type_~, ..) | Literal(type_~, ..) =>
      self.collect_checked_type(type_)
    Variant(generic_arguments~, arguments~, type_~, ..) => {
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_checked_pattern(argument)
      }
      self.collect_checked_type(type_)
    }
    Struct(fields~, type_~, ..) => {
      for field in fields {
        self.collect_checked_pattern(field.pattern)
      }
      self.collect_checked_type(type_)
    }
  }
}

///|
fn GenericParameterUseCollector::collect_expr(
  self : GenericParameterUseCollector,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_)
    | Extern(_) => ()
    QualifiedVariant(
      generic_arguments~,
      variant_generic_arguments~,
      arguments~,
      ..
    ) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_expr(argument)
      }
    }
    UnqualifiedVariant(variant_generic_arguments~, arguments~, ..) => {
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_expr(argument)
      }
    }
    ListLiteral(items~, ..) =>
      for item in items {
        self.collect_expr(item)
      }
    StructLiteral(generic_arguments~, fields~, ..) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for field in fields {
        self.collect_struct_literal_field(field)
      }
    }
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) => {
      self.add_parameters(type_parameters)
      for parameter in parameters {
        if parameter.type_annotation is Some(type_) {
          self.collect_type(type_)
        }
      }
      if return_type is Some(type_) {
        self.collect_type(type_)
      }
      if effect is Some(effect) {
        self.collect_effect(effect)
      }
      self.collect_expr(body)
    }
    EffectOperationCall(generic_witnesses~, arguments~, ..) => {
      for witness in generic_witnesses {
        self.collect_generic_argument(witness)
      }
      for argument in arguments {
        self.collect_expr(argument)
      }
    }
    GenericApplication(callee~, arguments~, ..) => {
      self.collect_expr(callee)
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      self.collect_expr(body)
      for handler in handlers {
        for arm in handler.arms {
          self.add_parameters(arm.type_binders)
          for pattern in arm.payload_patterns {
            self.collect_pattern(pattern)
          }
          self.collect_expr(arm.body)
        }
      }
      self.collect_expr(final_branch.body)
    }
    Block(items~, result~, ..) => {
      for item in items {
        self.collect_local_item(item)
      }
      self.collect_expr(result)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      self.collect_expr(condition)
      self.collect_expr(then_branch)
      self.collect_expr(else_branch)
    }
    Match(scrutinee~, arms~, ..) => {
      self.collect_expr(scrutinee)
      for arm in arms {
        self.collect_pattern(arm.pattern)
        self.collect_expr(arm.body)
      }
    }
    Call(callee~, arguments~, ..) => {
      self.collect_expr(callee)
      for argument in arguments {
        match argument {
          Positional(value~, ..) | Named(value~, ..) => self.collect_expr(value)
        }
      }
    }
    Field(base~, ..) => self.collect_expr(base)
    Unary(operand~, ..) => self.collect_expr(operand)
    Binary(left~, right~, ..) => {
      self.collect_expr(left)
      self.collect_expr(right)
    }
    Pipeline(left~, right~, ..) => {
      self.collect_expr(left)
      self.collect_expr(right)
    }
  }
}

///|
fn GenericParameterUseCollector::collect_struct_literal_field(
  self : GenericParameterUseCollector,
  field : @resolve.ResolvedStructLiteralField,
) -> Unit {
  match field {
    Value(value~, ..) => if value is Some(value) { self.collect_expr(value) }
    TypeWitness(witness~, ..) => self.collect_type(witness)
  }
}

///|
fn GenericParameterUseCollector::collect_pattern(
  self : GenericParameterUseCollector,
  pattern : @resolve.ResolvedPattern,
) -> Unit {
  match pattern {
    Wildcard(_)
    | Binding(_)
    | IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_) => ()
    QualifiedVariant(type_binders~, arguments~, ..) => {
      self.add_parameters(type_binders)
      for argument in arguments {
        self.collect_pattern(argument)
      }
    }
    UnqualifiedVariant(arguments~, ..) =>
      for argument in arguments {
        self.collect_pattern(argument)
      }
    Struct(fields~, ..) =>
      for field in fields {
        match field {
          Value(pattern~, ..) => self.collect_pattern(pattern)
          TypeBinder(type_parameter~, ..) =>
            self.add_parameters([type_parameter])
          TypeWildcard(type_parameter~, ..) =>
            self.add_parameters([type_parameter])
        }
      }
  }
}

///|
fn GenericParameterUseCollector::collect_type(
  self : GenericParameterUseCollector,
  type_ : @resolve.ResolvedType,
) -> Unit {
  match type_ {
    Primitive(_) | Constructor(_) | Alias(_) => ()
    Apply(callee~, arguments~, ..) => {
      self.collect_type(callee)
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    TypeLambda(parameters~, body~, ..) => {
      self.add_parameters(parameters)
      self.collect_type(body)
    }
    Parameter(symbol~, ..) => self.references.push(symbol)
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      self.add_parameters(type_parameters)
      for parameter in parameters {
        self.collect_type(parameter)
      }
      self.collect_type(result)
      self.collect_effect(effect)
    }
    Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
  }
}

///|
fn GenericParameterUseCollector::collect_effect(
  self : GenericParameterUseCollector,
  effect : @resolve.ResolvedEffectTerm,
) -> Unit {
  match effect {
    Empty(_) => ()
    Io(arguments~, ..) | Singleton(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    Parameter(symbol~, ..) => self.references.push(symbol)
    Alias(arguments~, ..) =>
      for argument in arguments {
        self.collect_effect_alias_argument(argument)
      }
    Union(items~, ..) =>
      for item in items {
        self.collect_effect(item)
      }
    Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_type(
  self : GenericParameterUseCollector,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Error | Primitive(_) | Constructor(_) => ()
    Apply(callee, arguments) => {
      self.collect_checked_type(callee)
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    TypeLambda(_, body) => self.collect_checked_type(body)
    Parameter(symbol) => self.references.push(symbol)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.collect_checked_type(parameter)
      }
      self.collect_checked_type(result)
      self.collect_checked_effect(effect)
    }
    Forall(_, body) => self.collect_checked_type(body)
  }
}

///|
fn GenericParameterUseCollector::collect_checked_effect(
  self : GenericParameterUseCollector,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty | Io => ()
    Singleton(_, arguments) =>
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    Parameter(symbol) => self.references.push(symbol)
    Union(effects) =>
      for effect in effects {
        self.collect_checked_effect(effect)
      }
  }
}

///|
fn GenericParameterUseCollector::collect_checked_generic_argument(
  self : GenericParameterUseCollector,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_checked_type(type_)
    EffectArgument(effect) => self.collect_checked_effect(effect)
  }
}

///|
fn GenericParameterUseCollector::collect_generic_argument(
  self : GenericParameterUseCollector,
  argument : @resolve.ResolvedGenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_type(type_)
    EffectArgument(effect) => self.collect_effect(effect)
  }
}

///|
fn GenericParameterUseCollector::collect_effect_alias_argument(
  self : GenericParameterUseCollector,
  argument : @resolve.ResolvedEffectAliasArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_type(type_)
    EffectArgument(effect) => self.collect_effect(effect)
  }
}

///|
fn GenericParameterUseKind::text(self : GenericParameterUseKind) -> String {
  match self {
    GenericTypeParameter => "type parameter"
    GenericEffectParameter => "effect parameter"
  }
}
