///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_local_span,
}

///|
priv enum GenericParameterKind {
  GenericTypeParameter
  GenericEffectParameter
}

///|
priv struct GenericParameterFact {
  symbol : @symbol.TypeParameterId
  name : String
  kind : GenericParameterKind
  loc : @basic.SourceSpan
}

///|
priv enum TopLevelSymbol {
  TopLevelValue(@symbol.ValueSymbolId)
  TopLevelType(@symbol.TypeSymbolId)
  TopLevelEffect(@symbol.EffectSymbolId)
  TopLevelAlias(@symbol.TypeAliasSymbolId)
} derive(Eq)

///|
priv enum TopLevelDeclarationKind {
  ValueDeclaration
  FunctionDeclaration
  StructDeclaration
  EnumDeclaration
  ExternalTypeDeclaration
  EffectDeclaration
  TypeAliasDeclaration
  EffectAliasDeclaration
}

///|
priv struct TopLevelDeclarationFact {
  symbol : TopLevelSymbol
  name : String
  kind : TopLevelDeclarationKind
  is_public : Bool
  name_loc : @basic.SourceSpan
  loc : @basic.SourceSpan
}

///|
priv struct TopLevelReferenceFact {
  from : TopLevelSymbol
  to : TopLevelSymbol
}

///|
priv struct LintCollector {
  registry : @symbol.SymbolRegistry
  generic_parameters : Array[GenericParameterFact]
  generic_parameter_references : Array[@symbol.TypeParameterId]
  used_import_symbols : Array[@resolve.ResolvedImportSymbol]
  top_level_declarations : Array[TopLevelDeclarationFact]
  top_level_references : Array[TopLevelReferenceFact]
  mut current_top_level : TopLevelSymbol?
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity~,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
  )
}

///|
pub fn checked_unused_local_value_binding_diagnostics(
  source : @checked.CheckedSourceFile,
  registry : @symbol.SymbolRegistry,
  _source_text : String,
) -> Array[CompilerDiagnostic] {
  source
  .value_use_analysis(registry)
  .unused_binders()
  .filter(fn(binder) { !binder.name.has_prefix("_") })
  .map(unused_local_value_binding_diagnostic)
}

///|
fn unused_local_value_binding_diagnostic(
  binder : @checked.CheckedValueUseBinder,
) -> CompilerDiagnostic {
  let binder_loc = binder.loc
  diagnostic(
    "unused local value binding",
    span=Some(binder_loc),
    severity=Warning,
    code=Some("W2001"),
    labels=[
      {
        span: compiler_local_span(binder_loc),
        message: "`\{binder.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=["prefix the name with `_` if this is intentional"],
  )
}

///|
pub fn checked_semantic_warning_diagnostics(
  source : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
  _source_text : String,
) -> Array[CompilerDiagnostic] {
  let collector = LintCollector::{
    registry: source.symbols,
    generic_parameters: [],
    generic_parameter_references: [],
    used_import_symbols: [],
    top_level_declarations: [],
    top_level_references: [],
    current_top_level: None,
  }
  collector.collect_source(source)
  collector.collect_checked_source(checked)
  let diagnostics = collector
    .unused_private_top_level_declarations()
    .map(unused_private_top_level_declaration_diagnostic)
  diagnostics.append(
    collector
    .unused_generic_parameters()
    .map(unused_generic_parameter_diagnostic),
  )
  diagnostics.append(collector.unused_import_exposure_diagnostics(source))
  diagnostics
}

///|
fn LintCollector::collect_source(
  self : LintCollector,
  source : @resolve.ResolvedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    self.add_top_level_declaration(declaration)
  }
  for declaration in source.declarations {
    let symbol = top_level_symbol(declaration)
    let previous = self.current_top_level
    self.current_top_level = Some(symbol)
    self.collect_declaration(declaration)
    self.current_top_level = previous
  }
}

///|
fn LintCollector::collect_checked_source(
  self : LintCollector,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    let previous = self.current_top_level
    self.current_top_level = Some(checked_top_level_symbol(declaration))
    self.collect_checked_declaration(declaration)
    self.current_top_level = previous
  }
}

///|
fn checked_top_level_symbol(
  declaration : @checked.CheckedTopLevelDeclaration,
) -> TopLevelSymbol {
  match declaration {
    Struct(declaration) => TopLevelType(declaration.symbol)
    Enum(declaration) => TopLevelType(declaration.symbol)
    ExternalType(declaration) => TopLevelType(declaration.symbol)
    Effect(declaration) => TopLevelEffect(declaration.symbol)
    Function(declaration) => TopLevelValue(declaration.symbol)
    Let(declaration) => TopLevelValue(declaration.symbol)
  }
}

///|
fn LintCollector::collect_checked_declaration(
  self : LintCollector,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> Unit {
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
      self.collect_checked_type(declaration.type_)
      self.collect_checked_expr(declaration.body)
    }
    Let(declaration) => {
      self.collect_checked_type(declaration.type_)
      self.collect_checked_expr(declaration.initializer)
    }
  }
}

///|
fn LintCollector::collect_checked_expr(
  self : LintCollector,
  expr : @checked.CheckedExpr,
) -> Unit {
  self.collect_checked_expr_types(expr)
  match expr {
    Match(arms~, ..) =>
      for arm in arms {
        self.collect_checked_pattern(arm.pattern)
      }
    Handler(handlers~, ..) =>
      for handler in handlers {
        for operation in handler.operations {
          for pattern in operation.payload_patterns {
            self.collect_checked_pattern(pattern)
          }
        }
      }
    _ => ()
  }
  expr.for_each_child_expr(fn(child) { self.collect_checked_expr(child) })
}

///|
fn LintCollector::collect_checked_expr_types(
  self : LintCollector,
  expr : @checked.CheckedExpr,
) -> Unit {
  match expr {
    Literal(type_~, ..)
    | CompilerIntrinsic(type_~, ..)
    | ExternBinding(type_~, ..)
    | ErrorRecovery(type_~, ..)
    | Block(type_~, ..)
    | If(type_~, ..)
    | Match(type_~, ..)
    | Call(type_~, ..)
    | FunctionEffectWiden(type_~, ..) => self.collect_checked_type(type_)
    Field(field~, type_~, ..) => {
      if self.registry.field_metadata(field) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      self.collect_checked_type(type_)
    }
    Value(symbol~, type_~, ..) => {
      guard self.registry.value_metadata(symbol) is Some(metadata) else {
        abort("lint analysis missing metadata for value#\{symbol.index}")
      }
      if metadata.provenance is Authored {
        self.use_import_symbol(ValueSymbol(symbol))
        self.add_top_level_reference(TopLevelValue(symbol))
      }
      self.collect_checked_type(type_)
    }
    FunctionLiteral(parameters~, return_type~, type_~, ..) => {
      for parameter in parameters {
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(return_type)
      self.collect_checked_type(type_)
    }
    GenericApplication(arguments~, type_~, ..) => {
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
    Derive(plan~, type_~, ..) => {
      self.collect_checked_type(plan.capability)
      self.collect_checked_type(plan.target)
      self.collect_checked_type(plan.shape.representation())
      plan.shape.for_each_evidence(fn(evidence) {
        self.collect_checked_type(evidence.required_type)
      })
      self.collect_checked_type(type_)
    }
    OperationCall(operation~, generic_witnesses~, effect~, type_~, ..) => {
      if self.registry.operation_metadata(operation) is Some(metadata) {
        self.add_top_level_reference(TopLevelEffect(metadata.owner))
      }
      for witness in generic_witnesses {
        self.collect_checked_generic_argument(witness)
      }
      self.collect_checked_effect(effect)
      self.collect_checked_type(type_)
    }
    Handler(handlers~, final_branch~, type_~, ..) => {
      for handler in handlers {
        self.collect_checked_effect(handler.handled_effect)
        for operation in handler.operations {
          if self.registry.operation_metadata(operation.operation)
            is Some(metadata) {
            self.add_top_level_reference(TopLevelEffect(metadata.owner))
          }
          for payload_type in operation.payload_types {
            self.collect_checked_type(payload_type)
          }
          self.collect_checked_type(operation.resume_type)
        }
      }
      self.collect_checked_type(final_branch.binder_type)
      self.collect_checked_type(type_)
    }
    StructLiteral(symbol~, generic_arguments~, type_witnesses~, type_~, ..) => {
      self.add_top_level_reference(TopLevelType(symbol))
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for witness in type_witnesses {
        self.collect_checked_generic_argument(witness.argument)
      }
      self.collect_checked_type(type_)
    }
    Variant(symbol~, generic_arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
  }
}

///|
fn LintCollector::collect_checked_pattern(
  self : LintCollector,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(type_~, ..) | Binding(type_~, ..) | Literal(type_~, ..) =>
      self.collect_checked_type(type_)
    Variant(symbol~, generic_arguments~, arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
      for argument in arguments {
        self.collect_checked_pattern(argument)
      }
    }
    Struct(symbol~, fields~, type_~, ..) => {
      self.add_top_level_reference(TopLevelType(symbol))
      self.collect_checked_type(type_)
      for field in fields {
        self.collect_checked_pattern(field.pattern)
      }
    }
  }
}

///|
fn LintCollector::collect_checked_type(
  self : LintCollector,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Constructor(symbol) => {
      self.use_import_symbol(TypeSymbol(symbol))
      self.add_top_level_reference(TopLevelType(symbol))
    }
    Error | Primitive(_) => ()
    Apply(callee, arguments) => {
      self.collect_checked_type(callee)
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    TypeLambda(_, body) | Forall(_, body) => self.collect_checked_type(body)
    Parameter(symbol) => self.generic_parameter_references.push(symbol)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.collect_checked_type(parameter)
      }
      self.collect_checked_type(result)
      self.collect_checked_effect(effect)
    }
  }
}

///|
fn LintCollector::collect_checked_effect(
  self : LintCollector,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty | Io => ()
    Singleton(symbol, arguments) => {
      self.use_import_symbol(EffectSymbol(symbol))
      self.add_top_level_reference(TopLevelEffect(symbol))
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    Parameter(symbol) => self.generic_parameter_references.push(symbol)
    Union(effects) =>
      for effect in effects {
        self.collect_checked_effect(effect)
      }
  }
}

///|
fn LintCollector::collect_checked_generic_argument(
  self : LintCollector,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_checked_type(type_)
    EffectArgument(effect) => self.collect_checked_effect(effect)
  }
}

///|
fn LintCollector::use_import_symbol(
  self : LintCollector,
  symbol : @resolve.ResolvedImportSymbol,
) -> Unit {
  if !self.used_import_symbols.contains(symbol) {
    self.used_import_symbols.push(symbol)
  }
}

///|
fn LintCollector::add_top_level_declaration(
  self : LintCollector,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  let fact = match declaration {
    Struct(declaration) =>
      {
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: StructDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    Enum(declaration) =>
      {
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: EnumDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    ExternalType(declaration) =>
      {
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: ExternalTypeDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    Effect(declaration) =>
      {
        symbol: TopLevelEffect(declaration.symbol),
        name: declaration.name,
        kind: EffectDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    TypeAlias(declaration) =>
      {
        symbol: TopLevelAlias(declaration.symbol),
        name: declaration.name,
        kind: match declaration.body {
          TypeBody(_) => TypeAliasDeclaration
          EffectBody(_) => EffectAliasDeclaration
        },
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    Function(declaration) =>
      {
        symbol: TopLevelValue(declaration.symbol),
        name: declaration.name,
        kind: FunctionDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
    Let(declaration) =>
      {
        symbol: TopLevelValue(declaration.symbol),
        name: declaration.name,
        kind: ValueDeclaration,
        is_public: declaration.is_public,
        name_loc: declaration.name_loc,
        loc: declaration.loc,
      }
  }
  self.top_level_declarations.push(fact)
}

///|
fn top_level_symbol(
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> TopLevelSymbol {
  match declaration {
    Struct(declaration) => TopLevelType(declaration.symbol)
    Enum(declaration) => TopLevelType(declaration.symbol)
    ExternalType(declaration) => TopLevelType(declaration.symbol)
    Effect(declaration) => TopLevelEffect(declaration.symbol)
    TypeAlias(declaration) => TopLevelAlias(declaration.symbol)
    Function(declaration) => TopLevelValue(declaration.symbol)
    Let(declaration) => TopLevelValue(declaration.symbol)
  }
}

///|
fn LintCollector::collect_declaration(
  self : LintCollector,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      self.add_generic_parameters(declaration.type_parameters)
      for struct_member in declaration.members {
        match struct_member {
          TypeMember(_) => ()
          Field(field) => self.collect_type(field.type_)
        }
      }
    }
    Enum(declaration) => {
      self.add_generic_parameters(declaration.type_parameters)
      for variant in declaration.variants {
        self.add_generic_parameters(variant.type_parameters)
        for payload in variant.payload {
          self.collect_type(payload)
        }
      }
    }
    ExternalType(declaration) =>
      self.add_generic_parameters(declaration.type_parameters)
    Effect(declaration) =>
      if declaration.flavor is Algebraic {
        self.add_generic_parameters(declaration.type_parameters)
        for operation in declaration.operations {
          self.add_generic_parameters(operation.type_parameters)
          for payload in operation.payload {
            self.collect_type(payload)
          }
          self.collect_type(operation.result)
        }
      }
    TypeAlias(declaration) => {
      self.add_generic_parameters(declaration.type_parameters)
      match declaration.body {
        TypeBody(type_) => self.collect_type(type_)
        EffectBody(effect) => self.collect_effect(effect)
      }
    }
    Function(declaration) => {
      self.add_generic_parameters(declaration.type_parameters)
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
  }
}

///|
fn LintCollector::collect_local_item(
  self : LintCollector,
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
      self.add_generic_parameters(declaration.type_parameters)
      for parameter in declaration.parameters {
        self.collect_type(parameter.type_)
      }
      self.collect_type(declaration.return_type)
      self.collect_effect(declaration.effect)
      self.collect_expr(declaration.body)
    }
    Expression(expression) => self.collect_expr(expression)
  }
}

///|
fn LintCollector::collect_expr(
  self : LintCollector,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  self.collect_expr_types(expr)
  self.collect_expr_symbols(expr)
  match expr {
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) => {
      self.add_generic_parameters(type_parameters)
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
    Block(items~, result~, ..) => {
      for item in items {
        self.collect_local_item(item)
      }
      self.collect_expr(result)
    }
    Match(scrutinee~, arms~, ..) => {
      self.collect_expr(scrutinee)
      for arm in arms {
        self.collect_pattern(arm.pattern)
        self.collect_expr(arm.body)
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      self.collect_expr(body)
      for handler in handlers {
        for arm in handler.arms {
          self.add_generic_parameters(arm.type_binders)
          self.collect_operation_name(arm.name)
          for pattern in arm.payload_patterns {
            self.collect_pattern(pattern)
          }
          self.collect_expr(arm.body)
        }
      }
      self.collect_expr(final_branch.body)
    }
    _ => expr.for_each_child_expr(fn(child) { self.collect_expr(child) })
  }
}

///|
fn LintCollector::collect_expr_types(
  self : LintCollector,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    QualifiedVariant(generic_arguments~, variant_generic_arguments~, ..) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
    }
    UnqualifiedVariant(variant_generic_arguments~, ..) =>
      for argument in variant_generic_arguments {
        self.collect_generic_argument(argument)
      }
    StructLiteral(generic_arguments~, fields~, ..) => {
      for argument in generic_arguments {
        self.collect_generic_argument(argument)
      }
      for field in fields {
        if field is TypeWitness(witness~, ..) {
          self.collect_generic_argument(witness)
        }
      }
    }
    EffectOperationCall(generic_witnesses~, ..) =>
      for witness in generic_witnesses {
        self.collect_generic_argument(witness)
      }
    GenericApplication(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    Derive(capability~, target~, ..) => {
      self.collect_type(capability)
      self.collect_type(target)
    }
    _ => ()
  }
}

///|
fn LintCollector::collect_expr_symbols(
  self : LintCollector,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    Var(reference~, ..) => self.collect_value_reference(reference)
    QualifiedVariant(reference~, ..) | UnqualifiedVariant(reference~, ..) =>
      self.collect_variant_reference(reference)
    StructLiteral(fields~, reference~, ..) => {
      self.collect_type_reference(reference)
      for field in fields {
        if field is Value(punned_reference=Some(reference), ..) {
          self.collect_value_reference(reference)
        }
      }
    }
    EffectOperationCall(name~, ..) => self.collect_operation_name(name)
    Handler(handlers~, ..) =>
      for handler in handlers {
        for arm in handler.arms {
          self.collect_operation_name(arm.name)
        }
      }
    Field(reference~, ..) => self.collect_field_reference(reference)
    Unary(target~, ..) | Binary(target~, ..) =>
      self.collect_value_reference(target.reference)
    _ => ()
  }
}

///|
fn LintCollector::collect_pattern(
  self : LintCollector,
  pattern : @resolve.ResolvedPattern,
) -> Unit {
  match pattern {
    QualifiedVariant(type_binders~, reference~, arguments~, ..) => {
      self.add_generic_parameters(type_binders)
      self.collect_variant_reference(reference)
      for argument in arguments {
        self.collect_pattern(argument)
      }
    }
    UnqualifiedVariant(type_binders~, arguments~, ..) => {
      self.add_generic_parameters(type_binders)
      for argument in arguments {
        self.collect_pattern(argument)
      }
    }
    Struct(reference~, fields~, ..) => {
      self.collect_type_reference(reference)
      for field in fields {
        match field {
          Value(pattern~, ..) => self.collect_pattern(pattern)
          TypeBinder(type_parameter~, ..) | TypeWildcard(type_parameter~, ..) =>
            self.add_generic_parameters([type_parameter])
        }
      }
    }
    Wildcard(_)
    | Binding(_)
    | IntegerLiteral(_)
    | FloatingLiteral(_)
    | StringLiteral(_)
    | CharLiteral(_)
    | BoolLiteral(_) => ()
  }
}

///|
fn LintCollector::collect_type(
  self : LintCollector,
  type_ : @resolve.ResolvedType,
) -> Unit {
  match type_ {
    Primitive(_) => ()
    Constructor(symbol~, ..) =>
      self.add_top_level_reference(TopLevelType(symbol))
    Alias(symbol~, ..) => self.add_top_level_reference(TopLevelAlias(symbol))
    Apply(callee~, arguments~, ..) => {
      self.collect_type(callee)
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    TypeLambda(parameters~, body~, ..) => {
      self.add_generic_parameters(parameters)
      self.collect_type(body)
    }
    Parameter(symbol~, ..) => self.generic_parameter_references.push(symbol)
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      self.add_generic_parameters(type_parameters)
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
fn LintCollector::collect_effect(
  self : LintCollector,
  effect : @resolve.ResolvedEffectTerm,
) -> Unit {
  match effect {
    Empty(_) => ()
    Io(arguments~, ..) | Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    Singleton(symbol~, arguments~, ..) => {
      self.add_top_level_reference(TopLevelEffect(symbol))
      for argument in arguments {
        self.collect_generic_argument(argument)
      }
    }
    Parameter(symbol~, ..) => self.generic_parameter_references.push(symbol)
    Alias(symbol~, arguments~, ..) => {
      self.add_top_level_reference(TopLevelAlias(symbol))
      for argument in arguments {
        match argument {
          TypeArgument(type_) => self.collect_type(type_)
          EffectArgument(effect) => self.collect_effect(effect)
        }
      }
    }
    Union(items~, ..) =>
      for item in items {
        self.collect_effect(item)
      }
  }
}

///|
fn LintCollector::collect_generic_argument(
  self : LintCollector,
  argument : @resolve.ResolvedGenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_type(type_)
    EffectArgument(effect) => self.collect_effect(effect)
  }
}

///|
fn LintCollector::collect_value_reference(
  self : LintCollector,
  reference : @resolve.ResolvedValueReference,
) -> Unit {
  if reference is Symbol(symbol) {
    self.add_top_level_reference(TopLevelValue(symbol))
  }
}

///|
fn LintCollector::collect_type_reference(
  self : LintCollector,
  reference : @resolve.ResolvedTypeReference,
) -> Unit {
  if reference is Symbol(symbol) {
    self.add_top_level_reference(TopLevelType(symbol))
  }
}

///|
fn LintCollector::collect_field_reference(
  self : LintCollector,
  reference : @resolve.ResolvedFieldReference,
) -> Unit {
  if reference is Symbol(symbol) &&
    self.registry.field_metadata(symbol) is Some(metadata) {
    self.add_top_level_reference(TopLevelType(metadata.owner))
  }
}

///|
fn LintCollector::collect_variant_reference(
  self : LintCollector,
  reference : @resolve.ResolvedVariantReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.variant_metadata(candidate) is Some(metadata) {
          self.add_top_level_reference(TopLevelType(metadata.owner))
        }
      }
    Unresolved(_) | UnresolvedUnqualified(_) => ()
  }
}

///|
fn LintCollector::collect_operation_name(
  self : LintCollector,
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
fn LintCollector::collect_operation_reference(
  self : LintCollector,
  reference : @resolve.ResolvedOperationReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.operation_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelEffect(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.operation_metadata(candidate) is Some(metadata) {
          self.add_top_level_reference(TopLevelEffect(metadata.owner))
        }
      }
    Unresolved(_) => ()
  }
}

///|
fn LintCollector::add_generic_parameters(
  self : LintCollector,
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Unit {
  for parameter in parameters {
    self.generic_parameters.push({
      symbol: parameter.symbol,
      name: parameter.name,
      kind: match parameter.kind {
        Some(Effect(_)) => GenericEffectParameter
        _ => GenericTypeParameter
      },
      loc: parameter.name_loc,
    })
  }
}

///|
fn LintCollector::add_top_level_reference(
  self : LintCollector,
  target : TopLevelSymbol,
) -> Unit {
  if self.current_top_level is Some(from) &&
    self.top_level_declarations.any(fn(declaration) {
      declaration.symbol == target
    }) {
    self.top_level_references.push({ from, to: target })
  }
}

///|
fn LintCollector::unused_private_top_level_declarations(
  self : LintCollector,
) -> Array[TopLevelDeclarationFact] {
  let reachable = []
  for declaration in self.top_level_declarations {
    if declaration.is_public {
      self.mark_top_level_reachable(declaration.symbol, reachable)
    }
  }
  let unused = self.top_level_declarations.filter(fn(declaration) {
    !declaration.is_public &&
    !declaration.name.has_prefix("_") &&
    !reachable.contains(declaration.symbol)
  })
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
fn LintCollector::mark_top_level_reachable(
  self : LintCollector,
  symbol : TopLevelSymbol,
  reachable : Array[TopLevelSymbol],
) -> Unit {
  if reachable.contains(symbol) {
    return
  }
  reachable.push(symbol)
  for reference in self.top_level_references {
    if reference.from == symbol {
      self.mark_top_level_reachable(reference.to, reachable)
    }
  }
}

///|
fn LintCollector::unused_generic_parameters(
  self : LintCollector,
) -> Array[GenericParameterFact] {
  let unused = self.generic_parameters.filter(fn(parameter) {
    !parameter.name.has_prefix("_") &&
    !self.generic_parameter_references.contains(parameter.symbol)
  })
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
fn unused_private_top_level_declaration_diagnostic(
  declaration : TopLevelDeclarationFact,
) -> CompilerDiagnostic {
  let declaration_loc = declaration.name_loc
  let kind = declaration.kind.text()
  diagnostic(
    "unused private top-level declaration",
    span=Some(declaration_loc),
    severity=Warning,
    code=Some("W2002"),
    labels=[
      {
        span: compiler_local_span(declaration_loc),
        message: "private \{kind} `\{declaration.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=[
      "remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional",
    ],
  )
}

///|
fn unused_generic_parameter_diagnostic(
  binder : GenericParameterFact,
) -> CompilerDiagnostic {
  let binder_loc = binder.loc
  let kind = binder.kind.text()
  diagnostic(
    "unused \{kind}",
    span=Some(binder_loc),
    severity=Warning,
    code=Some("W2003"),
    labels=[
      {
        span: compiler_local_span(binder_loc),
        message: "`\{binder.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=["prefix the name with `_` if this is intentional"],
  )
}

///|
fn LintCollector::unused_import_exposure_diagnostics(
  self : LintCollector,
  source : @resolve.ResolvedSourceFile,
) -> Array[CompilerDiagnostic] {
  let used_exposure_ids = []
  for use_ in source.import_uses {
    if !used_exposure_ids.contains(use_.exposure_id) {
      used_exposure_ids.push(use_.exposure_id)
    }
  }
  for exposure_symbol in source.import_symbols {
    if self.used_import_symbols.contains(exposure_symbol.symbol) &&
      !used_exposure_ids.contains(exposure_symbol.exposure_id) {
      used_exposure_ids.push(exposure_symbol.exposure_id)
    }
  }
  source.import_exposures
  .filter(fn(exposure) { !used_exposure_ids.contains(exposure.id) })
  .map(unused_import_exposure_diagnostic)
}

///|
fn unused_import_exposure_diagnostic(
  exposure : @resolve.ResolvedImportExposure,
) -> CompilerDiagnostic {
  let (message, label) = match exposure.kind {
    QualifiedModuleBinding(name~, ..) =>
      (
        "unused import",
        if name == exposure.module_path_text {
          "imported module `\{exposure.module_path_text}` is never used"
        } else {
          "imported module binding `\{name}` is never used"
        },
      )
    OpenBinding =>
      (
        "unused open import",
        "open import `\{exposure.module_path_text}.*` contributes no used names",
      )
    SelectiveBinding(name~) =>
      (
        "unused import item",
        "imported item `\{name}` from `\{exposure.module_path_text}` is never used",
      )
  }
  diagnostic(
    message,
    span=Some(exposure.loc),
    severity=Warning,
    code=Some("W2004"),
    labels=[
      {
        span: compiler_local_span(exposure.loc),
        message: label,
        style: Primary,
      },
    ],
    notes=[],
    helps=["remove the import or use a name provided by it"],
  )
}

///|
fn GenericParameterKind::text(self : GenericParameterKind) -> String {
  match self {
    GenericTypeParameter => "type parameter"
    GenericEffectParameter => "effect parameter"
  }
}

///|
fn TopLevelDeclarationKind::text(self : TopLevelDeclarationKind) -> String {
  match self {
    ValueDeclaration => "value"
    FunctionDeclaration => "function"
    StructDeclaration => "struct"
    EnumDeclaration => "enum"
    ExternalTypeDeclaration => "external type"
    EffectDeclaration => "effect"
    TypeAliasDeclaration => "type alias"
    EffectAliasDeclaration => "effect alias"
  }
}
