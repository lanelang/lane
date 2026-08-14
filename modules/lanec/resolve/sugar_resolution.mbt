///|
fn @abi.BasicTypeProvider::resolved_name(
  self : @abi.BasicTypeProvider,
) -> ResolvedNominalName {
  Qualified({ module_binding: self.module_path(), name: self.type_name() })
}

///|
fn Resolver::canonical_module_type_binding(
  self : Resolver,
  target : @abi.BasicTypeProvider,
) -> ModuleTypeBinding? {
  if target.module_path() == self.local_module.path_text {
    return ModuleNamespaceSource::LocalModule(self.local_module).type_binding(
      target.type_name(),
    )
  }
  match self.imported_module(target.module_path()) {
    Some(imported) =>
      ModuleNamespaceSource::ImportedModule(
        imported~,
        import_origins=imported.provider_origins,
        authored_binding_origin=None,
      ).type_binding(target.type_name())
    None => None
  }
}

///|
fn Resolver::resolve_canonical_type(
  self : Resolver,
  target : @abi.BasicTypeProvider,
  loc : SourceSpan,
) -> ResolvedType {
  let name = target.resolved_name()
  match self.canonical_module_type_binding(target) {
    Some(binding) => {
      self.record_import_uses(binding.import_origins, loc)
      match binding.kind {
        NominalType(symbol~, ..) => Constructor(symbol~, name~, loc~)
        TypeAlias(symbol~, ..) =>
          Alias(
            symbol~,
            owner_module_path=Some(binding.owner_module_path),
            name~,
            loc~,
          )
        EffectType(_) => {
          self.report(UnresolvedType(name.display_text()), loc)
          Unresolved(name=name.display_text(), arguments=[], loc~)
        }
      }
    }
    None => {
      self.report(UnresolvedType(name.display_text()), loc)
      Unresolved(name=name.display_text(), arguments=[], loc~)
    }
  }
}

///|
fn Resolver::resolve_canonical_variant(
  self : Resolver,
  target : @abi.BasicVariantProvider,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  let owner = target.owner()
  let type_name = owner.resolved_name()
  match self.canonical_module_type_binding(owner) {
    Some({ kind: NominalType(variants~, ..), import_origins, .. }) => {
      self.record_import_uses(import_origins, loc)
      for variant in variants {
        if variant.name == target.variant_name() {
          return Symbol(variant.symbol)
        }
      }
    }
    _ => ()
  }
  self.report(
    UnresolvedQualifiedVariant(
      type_name=type_name.display_text(),
      variant=target.variant_name(),
    ),
    loc,
  )
  Unresolved(type_name~, variant=target.variant_name())
}

///|
fn[T] right_nested(items : Array[T], combine : (T, T) -> T) -> T {
  guard items.length() >= 2 else {
    abort("tuple sugar must contain at least two items")
  }
  let mut result = items[items.length() - 1]
  for index = items.length() - 2; index >= 0; index = index - 1 {
    result = combine(items[index], result)
  }
  result
}

///|
fn @syntax.Type::resolve_tuple_type(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedType {
  guard self is Tuple(items~, loc~) else { abort("expected tuple type sugar") }
  let callee = resolver.resolve_canonical_type(Tuple, loc)
  let items = items.map(fn(item) { item.resolve_type(resolver, scope) })
  right_nested(items, fn(left, right) {
    Apply(callee~, arguments=[TypeArgument(left), TypeArgument(right)], loc~)
  })
}

///|
fn resolved_canonical_variant_expr(
  target : @abi.BasicVariantProvider,
  reference : ResolvedVariantReference,
  arguments : Array[ResolvedExpr],
  loc : SourceSpan,
) -> ResolvedExpr {
  QualifiedVariant(
    type_name=target.owner().resolved_name(),
    type_name_loc=loc,
    generic_arguments=[],
    variant=target.variant_name(),
    variant_loc=loc,
    variant_generic_arguments=[],
    reference~,
    arguments~,
    loc~,
  )
}

///|
fn @syntax.Expr::resolve_tuple_literal(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  guard self is TupleLiteral(items~, loc~) else {
    abort("expected tuple expression sugar")
  }
  let target = @abi.BasicVariantProvider::TupleValue
  let reference = resolver.resolve_canonical_variant(target, loc)
  let items = items.map(fn(item) { item.resolve_expr(resolver, scope) })
  right_nested(items, fn(left, right) {
    resolved_canonical_variant_expr(target, reference, [left, right], loc)
  })
}

///|
fn @syntax.Expr::resolve_list_literal(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  guard self is ListLiteral(items~, loc~) else {
    abort("expected list expression sugar")
  }
  if items.is_empty() {
    let target = @abi.BasicVariantProvider::ListEmpty
    let reference = resolver.resolve_canonical_variant(target, loc)
    return resolved_canonical_variant_expr(target, reference, [], loc)
  }
  let cons_target = @abi.BasicVariantProvider::ListCons
  let cons_reference = resolver.resolve_canonical_variant(cons_target, loc)
  let items = items.map(fn(item) { item.resolve_expr(resolver, scope) })
  let empty_target = @abi.BasicVariantProvider::ListEmpty
  let empty_reference = resolver.resolve_canonical_variant(empty_target, loc)
  let mut result = resolved_canonical_variant_expr(
    empty_target,
    empty_reference,
    [],
    loc,
  )
  for index = items.length(); index > 0; index = index - 1 {
    result = resolved_canonical_variant_expr(
      cons_target,
      cons_reference,
      [items[index - 1], result],
      loc,
    )
  }
  result
}

///|
fn resolved_canonical_variant_pattern(
  target : @abi.BasicVariantProvider,
  reference : ResolvedVariantReference,
  arguments : Array[ResolvedPattern],
  loc : SourceSpan,
) -> ResolvedPattern {
  QualifiedVariant(
    type_name=target.owner().resolved_name(),
    type_name_loc=loc,
    variant=target.variant_name(),
    variant_loc=loc,
    type_binders=[],
    reference~,
    arguments~,
    loc~,
  )
}

///|
fn @syntax.Pattern::resolve_tuple_pattern(
  self : @syntax.Pattern,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPattern {
  guard self is Tuple(items~, loc~) else {
    abort("expected tuple pattern sugar")
  }
  let target = @abi.BasicVariantProvider::TupleValue
  let reference = resolver.resolve_canonical_variant(target, loc)
  let items = items.map(fn(item) { item.resolve_pattern(resolver, scope) })
  right_nested(items, fn(left, right) {
    resolved_canonical_variant_pattern(target, reference, [left, right], loc)
  })
}
