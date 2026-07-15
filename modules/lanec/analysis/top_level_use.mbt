///|
priv enum TopLevelUseSymbol {
  TopLevelValueSymbol(@symbol.ValueSymbolId)
  TopLevelTypeSymbol(@symbol.TypeSymbolId)
  TopLevelEffectSymbol(@symbol.EffectSymbolId)
  TopLevelAliasSymbol(String)
} derive(Eq)

///|
priv enum TopLevelUseDeclarationKind {
  TopLevelValueDeclaration
  TopLevelFunctionDeclaration
  TopLevelStructDeclaration
  TopLevelEnumDeclaration
  TopLevelEffectDeclaration
  TopLevelTypeAliasDeclaration
  TopLevelEffectAliasDeclaration
}

///|
priv struct TopLevelUseDeclaration {
  symbol : TopLevelUseSymbol
  name : String
  kind : TopLevelUseDeclarationKind
  is_public : Bool
  loc : @basic.SourceSpan
}

///|
priv struct TopLevelUseEdge {
  from : TopLevelUseSymbol
  to : TopLevelUseSymbol
}

///|
priv struct TopLevelUseAnalysis {
  declarations : Array[TopLevelUseDeclaration]
  edges : Array[TopLevelUseEdge]
}

///|
priv struct TopLevelUseCollector {
  registry : @symbol.SymbolRegistry
  declarations : Array[TopLevelUseDeclaration]
  edges : Array[TopLevelUseEdge]
  mut current : TopLevelUseSymbol?
}

///|
fn @resolve.ResolvedSourceFile::top_level_use_analysis(
  self : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
) -> TopLevelUseAnalysis {
  let collector = TopLevelUseCollector::{
    registry: self.symbols,
    declarations: [],
    edges: [],
    current: None,
  }
  for declaration in self.declarations {
    collector.collect_declaration(declaration)
  }
  collector.collect_checked_source(checked)
  { declarations: collector.declarations, edges: collector.edges }
}

///|
fn TopLevelUseAnalysis::unused_private_declarations(
  self : TopLevelUseAnalysis,
) -> Array[TopLevelUseDeclaration] {
  let reachable = []
  for declaration in self.declarations {
    if declaration.is_public {
      self.mark_reachable_from(declaration.symbol, reachable)
    }
  }
  let unused = []
  for declaration in self.declarations {
    if !declaration.is_public &&
      !declaration.name.has_prefix("_") &&
      !reachable.contains(declaration.symbol) {
      unused.push(declaration)
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
fn TopLevelUseAnalysis::mark_reachable_from(
  self : TopLevelUseAnalysis,
  symbol : TopLevelUseSymbol,
  reachable : Array[TopLevelUseSymbol],
) -> Unit {
  if reachable.contains(symbol) {
    return
  }
  reachable.push(symbol)
  for edge in self.edges {
    if edge.from == symbol {
      self.mark_reachable_from(edge.to, reachable)
    }
  }
}

///|
fn TopLevelUseCollector::collect_declaration(
  self : TopLevelUseCollector,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      let symbol = TopLevelTypeSymbol(declaration.symbol)
      self.add_declaration(
        symbol,
        declaration.name,
        TopLevelStructDeclaration,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        for struct_member in declaration.members {
          collector.collect_struct_member(struct_member)
        }
      })
    }
    Enum(declaration) => {
      let symbol = TopLevelTypeSymbol(declaration.symbol)
      self.add_declaration(
        symbol,
        declaration.name,
        TopLevelEnumDeclaration,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        for variant in declaration.variants {
          for payload in variant.payload {
            collector.collect_type(payload)
          }
        }
      })
    }
    Effect(declaration) => {
      let symbol = TopLevelEffectSymbol(declaration.symbol)
      self.add_declaration(
        symbol,
        declaration.name,
        TopLevelEffectDeclaration,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        for operation in declaration.operations {
          for payload in operation.payload {
            collector.collect_type(payload)
          }
          collector.collect_type(operation.result)
        }
      })
    }
    TypeAlias(declaration) => {
      let symbol = TopLevelAliasSymbol(declaration.name)
      let kind = match declaration.body {
        TypeBody(_) => TopLevelTypeAliasDeclaration
        EffectBody(_) => TopLevelEffectAliasDeclaration
      }
      self.add_declaration(
        symbol,
        declaration.name,
        kind,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        match declaration.body {
          TypeBody(type_) => collector.collect_type(type_)
          EffectBody(effect) => collector.collect_effect(effect)
        }
      })
    }
    Function(declaration) => {
      let symbol = TopLevelValueSymbol(declaration.symbol)
      self.add_declaration(
        symbol,
        declaration.name,
        TopLevelFunctionDeclaration,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        for parameter in declaration.parameters {
          collector.collect_type(parameter.type_)
        }
        collector.collect_type(declaration.return_type)
        collector.collect_effect(declaration.effect)
        collector.collect_expr(declaration.body)
      })
    }
    Let(declaration) =>
      if declaration.name is Some(name) {
        let symbol = TopLevelValueSymbol(declaration.symbol)
        self.add_declaration(
          symbol,
          name,
          TopLevelValueDeclaration,
          declaration.is_public,
          declaration.loc,
        )
        self.with_current(symbol, fn(collector) {
          if declaration.type_annotation is Some(type_) {
            collector.collect_type(type_)
          }
          collector.collect_expr(declaration.initializer)
        })
      } else {
        self.collect_expr(declaration.initializer)
      }
    Offer(declaration) => {
      let symbol = TopLevelValueSymbol(declaration.symbol)
      self.add_declaration(
        symbol,
        declaration.name,
        TopLevelValueDeclaration,
        declaration.is_public,
        declaration.loc,
      )
      self.with_current(symbol, fn(collector) {
        collector.collect_type(declaration.type_annotation)
        collector.collect_expr(declaration.initializer)
      })
    }
  }
}

///|
fn TopLevelUseCollector::collect_checked_source(
  self : TopLevelUseCollector,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        self.with_current(TopLevelTypeSymbol(declaration.symbol), fn(
          collector,
        ) {
          for field in declaration.fields {
            collector.collect_checked_type(field.type_)
          }
        })
      Enum(declaration) =>
        self.with_current(TopLevelTypeSymbol(declaration.symbol), fn(
          collector,
        ) {
          for variant in declaration.variants {
            for payload in variant.payload {
              collector.collect_checked_type(payload)
            }
          }
        })
      Effect(declaration) =>
        self.with_current(TopLevelEffectSymbol(declaration.symbol), fn(
          collector,
        ) {
          for operation in declaration.operations {
            for payload in operation.payload {
              collector.collect_checked_type(payload)
            }
            collector.collect_checked_type(operation.result)
          }
        })
      Function(declaration) =>
        self.with_current(TopLevelValueSymbol(declaration.symbol), fn(
          collector,
        ) {
          for parameter in declaration.parameters {
            collector.collect_checked_type(parameter.type_)
          }
          collector.collect_checked_type(declaration.return_type)
          collector.collect_checked_expr(declaration.body)
        })
      Let(declaration) =>
        self.with_current(TopLevelValueSymbol(declaration.symbol), fn(
          collector,
        ) {
          collector.collect_checked_type(declaration.type_)
          collector.collect_checked_expr(declaration.initializer)
        })
    }
  }
}

///|
fn TopLevelUseCollector::with_current(
  self : TopLevelUseCollector,
  symbol : TopLevelUseSymbol,
  collect : (TopLevelUseCollector) -> Unit,
) -> Unit {
  let previous = self.current
  self.current = Some(symbol)
  collect(self)
  self.current = previous
}

///|
fn TopLevelUseCollector::add_declaration(
  self : TopLevelUseCollector,
  symbol : TopLevelUseSymbol,
  name : String,
  kind : TopLevelUseDeclarationKind,
  is_public : Bool,
  loc : @basic.SourceSpan,
) -> Unit {
  self.declarations.push({ symbol, name, kind, is_public, loc })
}

///|
fn TopLevelUseCollector::add_reference(
  self : TopLevelUseCollector,
  target : TopLevelUseSymbol,
) -> Unit {
  if self.declaration_index(target) is Some(_) {
    if self.current is Some(from) {
      self.edges.push({ from, to: target })
    }
  }
}

///|
fn TopLevelUseCollector::declaration_index(
  self : TopLevelUseCollector,
  symbol : TopLevelUseSymbol,
) -> Int? {
  for index, declaration in self.declarations {
    if declaration.symbol == symbol {
      return Some(index)
    }
  }
  None
}

///|
fn TopLevelUseCollector::collect_struct_member(
  self : TopLevelUseCollector,
  struct_member : @resolve.ResolvedStructMember,
) -> Unit {
  match struct_member {
    TypeMember(_) => ()
    Field(field) => self.collect_type(field.type_)
  }
}

///|
fn TopLevelUseCollector::collect_local_item(
  self : TopLevelUseCollector,
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
fn TopLevelUseCollector::collect_checked_local_item(
  self : TopLevelUseCollector,
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
fn TopLevelUseCollector::collect_checked_expr(
  self : TopLevelUseCollector,
  expr : @checked.CheckedExpr,
) -> Unit {
  match expr {
    Literal(type_~, ..) | UnsafeBuiltin(type_~, ..) =>
      self.collect_checked_type(type_)
    Value(symbol~, type_~, ..) => {
      self.add_reference(TopLevelValueSymbol(symbol))
      self.collect_checked_type(type_)
    }
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
    OperationCall(
      operation~,
      generic_witnesses~,
      arguments~,
      effect~,
      type_~,
      ..
    ) => {
      if self.registry.operation_metadata(operation) is Some(metadata) {
        self.add_reference(TopLevelEffectSymbol(metadata.owner))
      }
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
          if self.registry.operation_metadata(arm.operation) is Some(metadata) {
            self.add_reference(TopLevelEffectSymbol(metadata.owner))
          }
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
    Field(base~, field~, type_~, ..) => {
      self.collect_checked_expr(base)
      if self.registry.field_metadata(field) is Some(metadata) {
        self.add_reference(TopLevelTypeSymbol(metadata.owner))
      }
      self.collect_checked_type(type_)
    }
    StructLiteral(
      symbol~,
      generic_arguments~,
      type_witnesses~,
      fields~,
      type_~,
      ..
    ) => {
      self.add_reference(TopLevelTypeSymbol(symbol))
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
    Variant(symbol~, generic_arguments~, arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_reference(TopLevelTypeSymbol(metadata.owner))
      }
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
fn TopLevelUseCollector::collect_checked_pattern(
  self : TopLevelUseCollector,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(type_~, ..) | Binding(type_~, ..) | Literal(type_~, ..) =>
      self.collect_checked_type(type_)
    Variant(symbol~, generic_arguments~, arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_reference(TopLevelTypeSymbol(metadata.owner))
      }
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_checked_pattern(argument)
      }
      self.collect_checked_type(type_)
    }
    Struct(symbol~, fields~, type_~, ..) => {
      self.add_reference(TopLevelTypeSymbol(symbol))
      for field in fields {
        self.collect_checked_pattern(field.pattern)
      }
      self.collect_checked_type(type_)
    }
  }
}

///|
fn TopLevelUseCollector::collect_expr(
  self : TopLevelUseCollector,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Builtin(_) => ()
    Var(reference~, ..) => self.collect_value_reference(reference)
    QualifiedVariant(
      generic_arguments~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      ..
    ) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
      self.collect_variant_reference(reference)
      for argument in arguments {
        self.collect_expr(argument)
      }
    }
    UnqualifiedVariant(reference~, variant_generic_arguments~, arguments~, ..) => {
      self.collect_variant_reference(reference)
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in arguments {
        self.collect_expr(argument)
      }
    }
    ListLiteral(items~, empty_reference~, cons_reference~, ..) => {
      self.collect_variant_reference(empty_reference)
      if cons_reference is Some(cons_reference) {
        self.collect_variant_reference(cons_reference)
      }
      for item in items {
        self.collect_expr(item)
      }
    }
    StructLiteral(generic_arguments~, fields~, ..) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for field in fields {
        self.collect_struct_literal_field(field)
      }
    }
    FunctionLiteral(parameters~, return_type~, effect~, body~, ..) => {
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
    EffectOperationCall(name~, generic_witnesses~, arguments~, ..) => {
      self.collect_operation_name(name)
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
          self.collect_operation_name(arm.name)
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
    Field(base~, reference~, ..) => {
      self.collect_expr(base)
      self.collect_field_reference(reference)
    }
    Unary(reference~, operand~, ..) => {
      self.collect_value_reference(reference)
      self.collect_expr(operand)
    }
    Binary(reference~, left~, right~, ..) => {
      self.collect_value_reference(reference)
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
fn TopLevelUseCollector::collect_struct_literal_field(
  self : TopLevelUseCollector,
  field : @resolve.ResolvedStructLiteralField,
) -> Unit {
  match field {
    Value(value~, punned_reference~, ..) => {
      if value is Some(value) {
        self.collect_expr(value)
      }
      if punned_reference is Some(reference) {
        self.collect_value_reference(reference)
      }
    }
    TypeWitness(witness~, ..) => self.collect_type(witness)
  }
}

///|
fn TopLevelUseCollector::collect_pattern(
  self : TopLevelUseCollector,
  pattern : @resolve.ResolvedPattern,
) -> Unit {
  match pattern {
    Wildcard(_)
    | Binding(_)
    | IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_) => ()
    QualifiedVariant(reference~, arguments~, ..) => {
      self.collect_variant_reference(reference)
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
          TypeBinder(_) | TypeWildcard(_) => ()
        }
      }
  }
}

///|
fn TopLevelUseCollector::collect_type(
  self : TopLevelUseCollector,
  type_ : @resolve.ResolvedType,
) -> Unit {
  match type_ {
    Primitive(_) | Parameter(_) => ()
    Constructor(symbol~, ..) => self.add_reference(TopLevelTypeSymbol(symbol))
    Alias(name~, ..) => self.add_reference(TopLevelAliasSymbol(name))
    Apply(callee~, arguments~, ..) => {
      self.collect_type(callee)
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    TypeLambda(body~, ..) => self.collect_type(body)
    Function(parameters~, result~, effect~, ..) => {
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
fn TopLevelUseCollector::collect_effect(
  self : TopLevelUseCollector,
  effect : @resolve.ResolvedEffectTerm,
) -> Unit {
  match effect {
    Empty(_) | Parameter(_) => ()
    Io(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    Singleton(symbol~, arguments~, ..) => {
      self.add_reference(TopLevelEffectSymbol(symbol))
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    Alias(name~, arguments~, ..) => {
      self.add_reference(TopLevelAliasSymbol(name))
      for argument in arguments {
        self.collect_effect_alias_argument(argument)
      }
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
fn TopLevelUseCollector::collect_checked_type(
  self : TopLevelUseCollector,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Error | Primitive(_) | Parameter(_) => ()
    Constructor(symbol) => self.add_reference(TopLevelTypeSymbol(symbol))
    Apply(callee, arguments) => {
      self.collect_checked_type(callee)
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    TypeLambda(_, body) => self.collect_checked_type(body)
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
fn TopLevelUseCollector::collect_checked_effect(
  self : TopLevelUseCollector,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty | Io | Parameter(_) => ()
    Singleton(symbol, arguments) => {
      self.add_reference(TopLevelEffectSymbol(symbol))
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    Union(effects) =>
      for effect in effects {
        self.collect_checked_effect(effect)
      }
  }
}

///|
fn TopLevelUseCollector::collect_checked_generic_argument(
  self : TopLevelUseCollector,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_checked_type(type_)
    EffectArgument(effect) => self.collect_checked_effect(effect)
  }
}

///|
fn TopLevelUseCollector::collect_generic_argument(
  self : TopLevelUseCollector,
  argument : @resolve.ResolvedGenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_type(type_)
    EffectArgument(effect) => self.collect_effect(effect)
  }
}

///|
fn TopLevelUseCollector::collect_effect_alias_argument(
  self : TopLevelUseCollector,
  argument : @resolve.ResolvedEffectAliasArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_type(type_)
    EffectArgument(effect) => self.collect_effect(effect)
  }
}

///|
fn TopLevelUseCollector::collect_value_reference(
  self : TopLevelUseCollector,
  reference : @resolve.ResolvedValueReference,
) -> Unit {
  if reference is Symbol(symbol) {
    self.add_reference(TopLevelValueSymbol(symbol))
  }
}

///|
fn TopLevelUseCollector::collect_field_reference(
  self : TopLevelUseCollector,
  reference : @resolve.ResolvedFieldReference,
) -> Unit {
  if reference is Symbol(symbol) {
    if self.registry.field_metadata(symbol) is Some(metadata) {
      self.add_reference(TopLevelTypeSymbol(metadata.owner))
    }
  }
}

///|
fn TopLevelUseCollector::collect_variant_reference(
  self : TopLevelUseCollector,
  reference : @resolve.ResolvedVariantReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_reference(TopLevelTypeSymbol(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.variant_metadata(candidate) is Some(metadata) {
          self.add_reference(TopLevelTypeSymbol(metadata.owner))
        }
      }
    Unresolved(_) | UnresolvedUnqualified(_) => ()
  }
}

///|
fn TopLevelUseCollector::collect_operation_name(
  self : TopLevelUseCollector,
  name : @resolve.ResolvedEffectOperationName,
) -> Unit {
  match name {
    Qualified(owner~, reference~, ..) => {
      self.collect_effect(owner)
      self.collect_operation_reference(reference)
    }
    Unqualified(reference~, ..) => self.collect_operation_reference(reference)
  }
}

///|
fn TopLevelUseCollector::collect_operation_reference(
  self : TopLevelUseCollector,
  reference : @resolve.ResolvedOperationReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.operation_metadata(symbol) is Some(metadata) {
        self.add_reference(TopLevelEffectSymbol(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.operation_metadata(candidate) is Some(metadata) {
          self.add_reference(TopLevelEffectSymbol(metadata.owner))
        }
      }
    Unresolved(_) => ()
  }
}

///|
fn TopLevelUseDeclarationKind::text(
  self : TopLevelUseDeclarationKind,
) -> String {
  match self {
    TopLevelValueDeclaration => "value"
    TopLevelFunctionDeclaration => "function"
    TopLevelStructDeclaration => "struct"
    TopLevelEnumDeclaration => "enum"
    TopLevelEffectDeclaration => "effect"
    TopLevelTypeAliasDeclaration => "type alias"
    TopLevelEffectAliasDeclaration => "effect alias"
  }
}
