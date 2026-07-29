///|
/// Resolves a pattern and binds any pattern variables into the current arm scope.
///
/// Example: `Point::{ x }` resolves a struct pattern field, while `x` alone
/// creates a pattern binder rather than resolving a value reference.
fn @syntax.Pattern::resolve_pattern(
  self : @syntax.Pattern,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPattern {
  match self {
    Wildcard(loc) => Wildcard(loc)
    Binding(name, loc~) => {
      let symbol = resolver.registry.define_value(name, PatternBinder, loc)
      scope.define_value(name, symbol, None)
      Binding(name~, symbol~, loc~)
    }
    IntLiteral(value, loc~) => IntLiteral(value, loc~)
    DoubleLiteral(value, loc~) => DoubleLiteral(value, loc~)
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    QualifiedVariant(
      owner~,
      variant~,
      variant_loc~,
      type_binders~,
      arguments~,
      loc~
    ) => {
      let type_name = owner_type_name(owner)
      let type_name_loc = owner.loc()
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders.map(fn(binder) { binder.name }),
        loc,
      )
      scope.type_parameters.append(type_binders)
      QualifiedVariant(
        type_name~,
        type_name_loc~,
        variant~,
        variant_loc~,
        type_binders~,
        reference=resolver.variant_reference(
          type_name, variant, type_name_loc, variant_loc,
        ),
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    UnqualifiedVariant(variant~, variant_loc~, type_binders~, arguments~, loc~) => {
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders.map(fn(binder) { binder.name }),
        loc,
      )
      scope.type_parameters.append(type_binders)
      UnqualifiedVariant(
        variant~,
        variant_loc~,
        type_binders~,
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    Struct(owner~, fields~, loc~) => {
      let type_name = owner_type_name(owner)
      let type_name_loc = owner.loc()
      let reference = resolver.type_reference(type_name, type_name_loc)
      let owner = match reference {
        Symbol(symbol) => Some(symbol)
        Unresolved(_) => None
      }
      Struct(
        type_name~,
        type_name_loc~,
        reference~,
        fields=resolve_struct_pattern_fields(fields, resolver, scope, owner),
        loc~,
      )
    }
    Tuple(_) => self.resolve_tuple_pattern(resolver, scope)
  }
}

///|
/// Resolves one struct pattern field and its nested pattern.
///
/// Example: in `Point::{ x: Option::some(y) }`, the field name is kept and the
/// nested variant pattern is recursively resolved.
fn @syntax.StructPatternField::resolve_struct_pattern_field(
  self : @syntax.StructPatternField,
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId?,
) -> ResolvedStructPatternField {
  match self {
    Value(name~, pattern~, loc~) => {
      if pattern is None && owner_has_type_member(resolver, owner, name) {
        return resolver.resolve_pattern_type_binder(scope, name, loc)
      }
      let pattern = match pattern {
        Some(pattern) => pattern.resolve_pattern(resolver, scope)
        None => {
          let symbol = resolver.registry.define_value(name, PatternBinder, loc)
          scope.define_value(name, symbol, None)
          Binding(name~, symbol~, loc~)
        }
      }
      Value(name~, pattern~, loc~)
    }
    TypeBinder(name~, loc~) =>
      resolver.resolve_pattern_type_binder(scope, name, loc)
    TypeWildcard(loc~) => resolver.resolve_pattern_type_wildcard(scope, loc)
  }
}

///|
fn Resolver::resolve_pattern_type_binder(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  loc : SourceSpan,
) -> ResolvedStructPatternField {
  let symbol = self.registry.define_type_parameter(name, loc)
  let type_parameter = { symbol, name, name_loc: loc, kind: None, loc }
  scope.type_parameters.push(type_parameter)
  TypeBinder(name~, type_parameter~, loc~)
}

///|
fn Resolver::resolve_pattern_type_wildcard(
  self : Resolver,
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedStructPatternField {
  let symbol = self.registry.define_type_parameter("_", loc)
  let type_parameter : ResolvedTypeParameter = {
    symbol,
    name: "_",
    name_loc: loc,
    kind: None,
    loc,
  }
  scope.type_parameters.push(type_parameter)
  TypeWildcard(type_parameter~, loc~)
}

///|
fn owner_has_type_member(
  resolver : Resolver,
  owner : TypeSymbolId?,
  name : String,
) -> Bool {
  if owner is Some(owner) {
    resolver.type_has_member(owner, name)
  } else {
    false
  }
}

///|
fn resolve_struct_pattern_fields(
  fields : Array[@syntax.StructPatternField],
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId?,
) -> Array[ResolvedStructPatternField] {
  fields.map(fn(field) {
    field.resolve_struct_pattern_field(resolver, scope, owner)
  })
}
