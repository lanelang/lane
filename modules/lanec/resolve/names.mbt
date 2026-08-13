///|
priv enum UnqualifiedNameUse {
  BareUse(SourceSpan)
  CallUse(arguments~ : Array[@syntax.CallArgument], loc~ : SourceSpan)
}

///|
fn Resolver::operator_target(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  loc : SourceSpan,
) -> ResolvedOperatorTarget {
  let reference = scope.value_reference(name)
  self.record_import_use(scope.value_import_origin(reference), loc)
  self.report_unresolved_value(reference, loc)
  { name, reference }
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
fn Resolver::field_reference(
  self : Resolver,
  scope : ResolveScope,
  base : ResolvedExpr,
  name : String,
  loc : SourceSpan,
) -> ResolvedFieldReference {
  match nominal_type_of_expr(scope, base) {
    Some(symbol) =>
      match self.field_symbol_opt(symbol, name) {
        Some(field) => Symbol(field)
        None => {
          self.report_unresolved_field(symbol, name, loc)
          let type_name = match self.registry.type_metadata(symbol) {
            Some(metadata) => metadata.name
            None => "<unknown>"
          }
          Unresolved(type_name~, field=name)
        }
      }
    None => Deferred(name)
  }
}

///|
fn nominal_type_of_expr(
  scope : ResolveScope,
  expr : ResolvedExpr,
) -> TypeSymbolId? {
  match expr {
    Var(reference~, ..) =>
      match scope.value_type(reference) {
        Some(type_) =>
          match nominal_type_of_resolved_type(type_) {
            Some(symbol) => Some(symbol)
            None => None
          }
        _ => None
      }
    StructLiteral(reference=Symbol(symbol), ..) => Some(symbol)
    _ => None
  }
}

///|
fn nominal_type_of_resolved_type(type_ : ResolvedType) -> TypeSymbolId? {
  match type_ {
    Constructor(symbol~, ..) => Some(symbol)
    Apply(callee=Constructor(symbol~, ..), ..) => Some(symbol)
    _ => None
  }
}

///|
/// Resolves an unqualified source name in value position.
///
/// Example: `none` and `none()` both start from the same visible name. A visible
/// value named `none` wins first; otherwise the name may fall back to an
/// unqualified enum variant. Payloadless variants are still constructors, so
/// `none()` is the valid form and bare `none` is diagnosed here.
fn Resolver::resolve_unqualified_name_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
) -> ResolvedExpr {
  self.resolve_unqualified_name_use_with_variant_arguments(
    scope,
    name,
    name_loc,
    name_use,
    [],
  )
}

///|
fn Resolver::resolve_unqualified_name_use_with_variant_arguments(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
  variant_generic_arguments : Array[@syntax.GenericArgument],
) -> ResolvedExpr {
  match scope.value_reference(name) {
    Symbol(_) as reference => {
      self.record_import_use(scope.value_import_origin(reference), name_loc)
      name_use.resolve_as_value(self, scope, name, name_loc, reference)
    }
    Unresolved(_) =>
      self.resolve_unqualified_variant_use(
        scope, name, name_loc, name_use, variant_generic_arguments,
      )
  }
}

///|
fn Resolver::resolve_unqualified_variant_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
  variant_generic_arguments : Array[@syntax.GenericArgument],
) -> ResolvedExpr {
  match self.unqualified_variant_reference(name, name_loc) {
    Symbol(symbol) as reference => {
      name_use.report_payloadless_variant_without_parens(self, symbol, name)
      name_use.resolve_as_variant(
        self, scope, name, name_loc, variant_generic_arguments, reference,
      )
    }
    Ambiguous(_) as reference =>
      name_use.resolve_as_variant(
        self, scope, name, name_loc, variant_generic_arguments, reference,
      )
    Unresolved(..) | UnresolvedUnqualified(_) =>
      name_use.resolve_as_unresolved_value(self, scope, name, name_loc)
  }
}

///|
fn Resolver::resolve_module_value_field_chain(
  self : Resolver,
  scope : ResolveScope,
  expr : @syntax.Expr,
  loc : SourceSpan,
) -> ResolvedExpr? {
  guard dotted_segments(expr) is Some(segments) else { return None }
  if segments.length() < 2 {
    return None
  }
  let full_name = segments.join(".")
  let module_path_text = dotted_prefix_text(segments, segments.length() - 1)
  let value_name = segments[segments.length() - 1]
  match self.module_binding(module_path_text) {
    Some(module_) => {
      let qualifier_loc = match expr {
        Field(base~, ..) => base.loc()
        _ => loc
      }
      self.record_module_binding_reference(module_.import_origin, qualifier_loc)
      if scope.value_reference(segments[0]) is Symbol(_) {
        self.report(AmbiguousModuleValue(full_name), loc)
        return Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
      }
      for value in module_.imported.interface.values {
        if value.name == value_name {
          return Some(Var(name=full_name, reference=Symbol(value.symbol), loc~))
        }
      }
      self.report(UnresolvedValue(full_name), loc)
      Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
    }
    None =>
      if self.has_imported_module_prefix(segments) {
        self.report(UnresolvedValue(full_name), loc)
        Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
      } else {
        None
      }
  }
}

///|
fn dotted_segments(expr : @syntax.Expr) -> Array[String]? {
  match expr {
    Var(name, ..) => Some([name])
    Field(base~, name~, ..) =>
      match dotted_segments(base) {
        Some(segments) => {
          segments.push(name)
          Some(segments)
        }
        None => None
      }
    _ => None
  }
}

///|
fn dotted_prefix_text(segments : Array[String], end : Int) -> String {
  let prefix = []
  for index in 0..<end {
    prefix.push(segments[index])
  }
  prefix.join(".")
}

///|
fn Resolver::module_binding(
  self : Resolver,
  name_text : String,
) -> ModuleBinding? {
  for binding in self.module_bindings {
    if binding.name_text == name_text {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::imported_module(
  self : Resolver,
  path_text : String,
) -> ImportedModule? {
  for imported in self.imported_modules {
    if imported.path_text == path_text {
      return Some(imported)
    }
  }
  None
}

///|
fn Resolver::module_namespace_source(
  self : Resolver,
  name_text : String,
) -> ModuleNamespaceSource? {
  if name_text == self.local_module.path_text {
    Some(LocalModule(self.local_module))
  } else {
    match self.module_binding(name_text) {
      Some(binding) =>
        Some(
          ImportedModule(
            imported=binding.imported,
            import_origins=optional_import_origin(binding.import_origin),
            authored_binding_origin=binding.import_origin,
          ),
        )
      None => None
    }
  }
}

///|
fn Resolver::resolve_authored_module_namespace(
  self : Resolver,
  name_text : String,
  qualifier_loc : SourceSpan,
) -> ModuleNamespaceSource? {
  match self.module_namespace_source(name_text) {
    Some(source) => {
      match source {
        ImportedModule(authored_binding_origin~, ..) =>
          self.record_module_binding_reference(
            authored_binding_origin, qualifier_loc,
          )
        LocalModule(_) => ()
      }
      Some(source)
    }
    None => None
  }
}

///|
fn ModuleNamespaceSource::type_binding(
  self : ModuleNamespaceSource,
  name : String,
) -> ModuleTypeBinding? {
  match self {
    LocalModule(local_module) => {
      for binding in local_module.types {
        if binding.name == name {
          return Some({
            owner_module_path: local_module.path_text,
            parameter_kinds: binding.parameter_kinds,
            kind: NominalType(symbol=binding.symbol, variants=binding.variants),
            import_origins: [],
          })
        }
      }
      for binding in local_module.effects {
        if binding.name == name {
          return Some({
            owner_module_path: local_module.path_text,
            parameter_kinds: binding.parameter_kinds,
            kind: EffectType(binding.symbol),
            import_origins: [],
          })
        }
      }
      for binding in local_module.type_aliases {
        if binding.name == name {
          return Some({
            owner_module_path: local_module.path_text,
            parameter_kinds: binding.parameter_kinds,
            kind: TypeAlias(symbol=binding.symbol, is_effect=binding.is_effect),
            import_origins: [],
          })
        }
      }
      None
    }
    ImportedModule(imported~, import_origins~, ..) => {
      for type_ in imported.interface.types {
        match type_ {
          Struct(declaration) if declaration.name == name =>
            return Some({
              owner_module_path: imported.path_text,
              parameter_kinds: interface_type_parameter_kinds(
                declaration.type_parameters,
              ),
              kind: NominalType(symbol=declaration.symbol, variants=[]),
              import_origins,
            })
          Enum(declaration) if declaration.name == name =>
            return Some({
              owner_module_path: imported.path_text,
              parameter_kinds: interface_type_parameter_kinds(
                declaration.type_parameters,
              ),
              kind: NominalType(
                symbol=declaration.symbol,
                variants=declaration.variants.map(fn(variant) {
                  { name: variant.name, symbol: variant.symbol }
                }),
              ),
              import_origins,
            })
          External(declaration) if declaration.name == name =>
            return Some({
              owner_module_path: imported.path_text,
              parameter_kinds: [],
              kind: NominalType(symbol=declaration.symbol, variants=[]),
              import_origins,
            })
          _ => ()
        }
      }
      for effect in imported.interface.effects {
        if effect.name == name {
          return Some({
            owner_module_path: imported.path_text,
            parameter_kinds: interface_type_parameter_kinds(
              effect.type_parameters,
            ),
            kind: EffectType(effect.symbol),
            import_origins,
          })
        }
      }
      for type_alias in imported.interface.type_aliases {
        if type_alias.name == name {
          return Some({
            owner_module_path: imported.path_text,
            parameter_kinds: interface_type_parameter_kinds(
              type_alias.type_parameters,
            ),
            kind: TypeAlias(
              symbol=type_alias.symbol,
              is_effect=type_alias.kind == Effect,
            ),
            import_origins,
          })
        }
      }
      None
    }
  }
}

///|
fn Resolver::module_type_binding(
  self : Resolver,
  module_path : String,
  name : String,
) -> ModuleTypeBinding? {
  match self.module_namespace_source(module_path) {
    Some(source) => source.type_binding(name)
    None => None
  }
}

///|
fn Resolver::has_imported_module_prefix(
  self : Resolver,
  segments : Array[String],
) -> Bool {
  for end in 1..<(segments.length() - 1) {
    if self.module_binding(dotted_prefix_text(segments, end)) is Some(_) {
      return true
    }
  }
  false
}

///|
fn UnqualifiedNameUse::resolve_as_value(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  reference : ResolvedValueReference,
) -> ResolvedExpr {
  match self {
    BareUse(loc) => Var(name~, reference~, loc~)
    CallUse(arguments~, loc~) =>
      Call(
        callee=Var(name~, reference~, loc=name_loc),
        arguments=arguments.map(fn(argument) {
          argument.resolve_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
fn UnqualifiedNameUse::resolve_as_variant(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  variant_generic_arguments : Array[@syntax.GenericArgument],
  reference : ResolvedVariantReference,
) -> ResolvedExpr {
  let resolved_variant_generic_arguments = variant_generic_arguments.map(fn(
    argument,
  ) {
    argument.resolve_generic_argument(resolver, scope)
  })
  match self {
    BareUse(loc) =>
      UnqualifiedVariant(
        variant=name,
        variant_loc=name_loc,
        variant_generic_arguments=resolved_variant_generic_arguments,
        reference~,
        arguments=[],
        loc~,
      )
    CallUse(arguments~, loc~) =>
      UnqualifiedVariant(
        variant=name,
        variant_loc=name_loc,
        variant_generic_arguments=resolved_variant_generic_arguments,
        reference~,
        arguments=arguments.map(fn(argument) {
          argument.resolve_positional_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
fn UnqualifiedNameUse::resolve_as_unresolved_value(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
) -> ResolvedExpr {
  resolver.report(UnresolvedValue(name), self.loc())
  self.resolve_as_value(resolver, scope, name, name_loc, Unresolved(name))
}

///|
fn UnqualifiedNameUse::loc(self : UnqualifiedNameUse) -> SourceSpan {
  match self {
    BareUse(loc) | CallUse(loc~, ..) => loc
  }
}

///|
fn Resolver::scope(
  self : Resolver,
  type_parameters : Array[ResolvedTypeParameter],
) -> ResolveScope {
  { values: self.top_values.copy(), type_parameters: type_parameters.copy() }
}

///|
fn Resolver::ordered_scope(
  self : Resolver,
  type_parameters : Array[ResolvedTypeParameter],
) -> ResolveScope {
  {
    values: self.ordered_top_values.copy(),
    type_parameters: type_parameters.copy(),
  }
}

///|
fn Resolver::type_symbol(self : Resolver, name : String) -> TypeSymbolId {
  self.type_binding(name).unwrap().symbol
}

///|
fn Resolver::type_reference(
  self : Resolver,
  name : ResolvedNominalName,
  loc : SourceSpan,
) -> ResolvedTypeReference {
  match name {
    Unqualified(name) =>
      match self.type_binding(name) {
        Some(binding) => {
          self.record_import_use(binding.import_origin, loc)
          Symbol(binding.symbol)
        }
        None => Unresolved(Unqualified(name))
      }
    Qualified(qualified) =>
      match
        self.resolve_authored_module_namespace(
          qualified.module_binding,
          loc.ascii_prefix(qualified.module_binding.length()),
        ) {
        Some(source) =>
          match source.type_binding(qualified.name) {
            Some({ kind: NominalType(symbol~, ..), import_origins, .. }) => {
              self.record_import_uses(import_origins, loc)
              Symbol(symbol)
            }
            _ => Unresolved(name)
          }
        None => Unresolved(name)
      }
  }
}

///|
fn Resolver::variant_reference(
  self : Resolver,
  type_name : ResolvedNominalName,
  variant : String,
  type_name_loc : SourceSpan,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  match type_name {
    Qualified(qualified) =>
      match
        self.resolve_authored_module_namespace(
          qualified.module_binding,
          type_name_loc.ascii_prefix(qualified.module_binding.length()),
        ) {
        Some(source) =>
          match source.type_binding(qualified.name) {
            Some({ kind: NominalType(variants~, ..), import_origins, .. }) => {
              self.record_import_uses(import_origins, loc)
              for item in variants {
                if item.name == variant {
                  return Symbol(item.symbol)
                }
              }
            }
            _ => ()
          }
        None => ()
      }
    Unqualified(name) =>
      if self.type_binding(name) is Some(binding) {
        self.record_import_use(binding.import_origin, loc)
        for item in binding.variants {
          if item.name == variant {
            return Symbol(item.symbol)
          }
        }
      }
  }
  resolver_report_qualified_variant(
    self,
    type_name.display_text(),
    variant,
    loc,
  )
  Unresolved(type_name~, variant~)
}

///|
fn Resolver::type_binding(self : Resolver, name : String) -> TypeBinding? {
  for index = self.types.length(); index > 0; index = index - 1 {
    let binding = self.types[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::type_binding_for_symbol(
  self : Resolver,
  symbol : TypeSymbolId,
) -> TypeBinding? {
  for binding in self.types {
    if binding.symbol == symbol {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::field_symbol_opt(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> FieldSymbolId? {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    for field in binding.fields {
      if field.name == name {
        return Some(field.symbol)
      }
    }
  }
  for imported in self.imported_modules {
    for type_ in imported.interface.types {
      if type_ is Struct(declaration) && declaration.symbol == owner {
        for field in declaration.fields {
          if field.name == name {
            return Some(field.symbol)
          }
        }
      }
    }
  }
  None
}

///|
fn Resolver::field_symbol(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> FieldSymbolId {
  self.field_symbol_opt(owner, name).unwrap()
}

///|
fn Resolver::type_has_member(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> Bool {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    return binding.type_members.contains(name)
  }
  for imported in self.imported_modules {
    for type_ in imported.interface.types {
      if type_ is Struct(declaration) && declaration.symbol == owner {
        return declaration.type_members.any(fn(item) { item.name == name })
      }
    }
  }
  false
}

///|
fn Resolver::type_import_origin(self : Resolver, symbol : TypeSymbolId) -> Int? {
  for binding in self.types {
    if binding.symbol == symbol {
      return binding.import_origin
    }
  }
  None
}

///|
fn Resolver::publish_type_binding(
  self : Resolver,
  name : String,
  symbol : TypeSymbolId,
  parameter_kinds : Array[@types.Kind],
  type_members? : Array[String] = [],
  fields? : Array[FieldBinding] = [],
  variants? : Array[VariantBinding] = [],
  import_origin : Int?,
) -> Unit {
  self.types.push({
    name,
    symbol,
    parameter_kinds,
    type_members,
    fields,
    variants,
    import_origin,
  })
  self.record_import_symbol(import_origin, TypeSymbol(symbol))
}

///|
fn Resolver::publish_local_type_binding(
  self : Resolver,
  name : String,
  symbol : TypeSymbolId,
  parameter_kinds : Array[@types.Kind],
) -> Unit {
  self.publish_type_binding(name, symbol, parameter_kinds, None)
  self.local_module.types.push(self.types[self.types.length() - 1])
}

///|
fn Resolver::effect_symbol(self : Resolver, name : String) -> EffectSymbolId {
  self.effect_binding(name).unwrap().symbol
}

///|
fn Resolver::effect_symbol_opt(
  self : Resolver,
  name : String,
) -> EffectSymbolId? {
  self.effect_binding(name).map(fn(binding) { binding.symbol })
}

///|
fn Resolver::effect_binding(self : Resolver, name : String) -> EffectBinding? {
  for index = self.effects.length(); index > 0; index = index - 1 {
    let binding = self.effects[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::effect_binding_for_symbol(
  self : Resolver,
  symbol : EffectSymbolId,
) -> EffectBinding? {
  for binding in self.effects {
    if binding.symbol == symbol {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::effect_import_origin(
  self : Resolver,
  symbol : EffectSymbolId,
) -> Int? {
  for binding in self.effects {
    if binding.symbol == symbol {
      return binding.import_origin
    }
  }
  None
}

///|
fn Resolver::publish_effect_binding(
  self : Resolver,
  name : String,
  symbol : EffectSymbolId,
  parameter_kinds : Array[@types.Kind],
  operations? : Array[OperationBinding] = [],
  import_origin : Int?,
) -> Unit {
  self.effects.push({ name, symbol, parameter_kinds, operations, import_origin })
  self.record_import_symbol(import_origin, EffectSymbol(symbol))
}

///|
fn Resolver::publish_local_effect_binding(
  self : Resolver,
  name : String,
  symbol : EffectSymbolId,
  parameter_kinds : Array[@types.Kind],
) -> Unit {
  self.publish_effect_binding(name, symbol, parameter_kinds, None)
  self.local_module.effects.push(self.effects[self.effects.length() - 1])
}

///|
fn Resolver::operation_reference(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
  loc : SourceSpan,
) -> ResolvedOperationReference {
  match self.operation_binding(owner, name) {
    Some(symbol) => Symbol(symbol)
    None => {
      self.report(UnresolvedEffectOperation(name), loc)
      Unresolved(name)
    }
  }
}

///|
fn Resolver::unqualified_operation_reference(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> ResolvedOperationReference {
  let candidates = []
  for binding in self.effects {
    for operation in binding.operations {
      if operation.name == name && !candidates.contains(operation.symbol) {
        candidates.push(operation.symbol)
      }
    }
  }
  match candidates.length() {
    0 => {
      self.report(UnresolvedEffectOperation(name), loc)
      Unresolved(name)
    }
    1 => {
      if self.registry.operation_metadata(candidates[0]) is Some(metadata) {
        self.record_import_use(self.effect_import_origin(metadata.owner), loc)
      }
      Symbol(candidates[0])
    }
    _ => Ambiguous(name~, candidates~)
  }
}

///|
fn Resolver::operation_symbol(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId {
  self.operation_binding(owner, name).unwrap()
}

///|
fn Resolver::operation_binding(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId? {
  if self.effect_binding_for_symbol(owner) is Some(binding) {
    for operation in binding.operations {
      if operation.name == name {
        return Some(operation.symbol)
      }
    }
  }
  for imported in self.imported_modules {
    for effect in imported.interface.effects {
      if effect.symbol == owner {
        for operation in effect.operations {
          if operation.name == name {
            return Some(operation.symbol)
          }
        }
      }
    }
  }
  None
}

///|
fn Resolver::value_symbol(self : Resolver, name : String) -> ValueSymbolId {
  for binding in self.top_values {
    if binding.name == name {
      if binding.reference is Symbol(symbol) {
        return symbol
      }
    }
  }
  abort("missing predeclared value symbol")
}

///|
fn Resolver::top_value_binding(self : Resolver, name : String) -> ValueBinding? {
  for index = self.top_values.length(); index > 0; index = index - 1 {
    let binding = self.top_values[index - 1]
    if binding.name == name && binding.kind == Plain {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::ordered_top_value_binding(
  self : Resolver,
  name : String,
) -> ValueBinding? {
  for index = self.ordered_top_values.length(); index > 0; index = index - 1 {
    let binding = self.ordered_top_values[index - 1]
    if binding.name == name && binding.kind == Plain {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::publish_complete_top_level_binding(
  self : Resolver,
  binding : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  match binding.kind {
    Plain =>
      match self.top_value_binding(binding.name) {
        Some(existing) =>
          if !self.has_conflicting_top_value_name(binding.name) {
            self.report_conflicting_top_level_value(binding, existing, loc)
          }
        None => self.top_values.push(binding)
      }
  }
}

///|
fn Resolver::publish_ordered_top_level_binding(
  self : Resolver,
  binding : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  match binding.kind {
    Plain =>
      match self.ordered_top_value_binding(binding.name) {
        Some(existing) =>
          if !self.has_conflicting_top_value_name(binding.name) {
            self.report_conflicting_top_level_value(binding, existing, loc)
          }
        None => self.ordered_top_values.push(binding)
      }
  }
}

///|
fn Resolver::has_conflicting_top_value_name(
  self : Resolver,
  name : String,
) -> Bool {
  self.conflicting_top_value_names.any(fn(conflicting) { conflicting == name })
}

///|
fn Resolver::variant_symbol(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> VariantSymbolId {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    for variant in binding.variants {
      if variant.name == name {
        return variant.symbol
      }
    }
  }
  abort("missing predeclared variant symbol")
}

///|
fn Resolver::unqualified_variant_reference(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  let candidates = []
  for binding in self.types {
    for variant in binding.variants {
      if variant.name == name && !candidates.contains(variant.symbol) {
        candidates.push(variant.symbol)
      }
    }
  }
  match candidates.length() {
    0 => UnresolvedUnqualified(name)
    1 => {
      if self.registry.variant_metadata(candidates[0]) is Some(metadata) {
        self.record_import_use(self.type_import_origin(metadata.owner), loc)
      }
      Symbol(candidates[0])
    }
    _ => {
      self.report(
        AmbiguousUnqualifiedVariant(
          name~,
          candidates=candidates.map(fn(candidate) {
            self.variant_candidate(candidate)
          }),
        ),
        loc,
      )
      Ambiguous(name~, candidates~)
    }
  }
}

///|
fn Resolver::variant_candidate(
  self : Resolver,
  symbol : VariantSymbolId,
) -> ResolveVariantCandidate {
  match self.registry.variant_metadata(symbol) {
    Some(variant) =>
      match self.registry.type_metadata(variant.owner) {
        Some(owner) => { owner: owner.name, variant: variant.name }
        None => { owner: "<unknown>", variant: variant.name }
      }
    None => { owner: "<unknown>", variant: "<unknown>" }
  }
}
