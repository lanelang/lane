///|
/// Resolves a source type expression into primitive, parameter, nominal, or
/// unresolved resolved-type nodes.
///
/// Example: `A` in a generic scope resolves to a type parameter, while
/// `Option[Int]` resolves to a nominal type application.
fn @syntax.Type::resolve_type(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedType {
  match self {
    Name(name~, loc~) =>
      // Type names are resolved in the language order: primitives first, then
      // in-scope type parameters, then nominal type constructors, then aliases.
      match primitive_type(name) {
        Some(primitive) => Primitive(primitive, loc~)
        None =>
          match scope.type_parameter(name) {
            Some(symbol) => Parameter(symbol~, name~, loc~)
            None =>
              match resolver.type_binding(name) {
                Some(binding) => {
                  resolver.record_import_use(binding.import_origin, loc)
                  Constructor(
                    symbol=binding.symbol,
                    name=Unqualified(name),
                    loc~,
                  )
                }
                None =>
                  match resolver.type_alias_binding(name) {
                    Some(binding) => {
                      resolver.record_import_use(binding.import_origin, loc)
                      Alias(
                        symbol=binding.symbol,
                        owner_module_path=binding.owner_module_path,
                        name=Unqualified(name),
                        loc~,
                      )
                    }
                    None => {
                      resolver.report(UnresolvedType(name), loc)
                      Unresolved(name~, arguments=[], loc~)
                    }
                  }
              }
          }
      }
    QualifiedName(module_path~, name~, loc~) =>
      resolver.resolve_module_qualified_type(module_path, name, loc)
    Apply(callee~, arguments~, loc~) => {
      let resolved_callee = callee.resolve_type(resolver, scope)
      Apply(
        callee=resolved_callee,
        arguments=callee.resolve_type_application_arguments(
          resolved_callee, arguments, resolver, scope,
        ),
        loc~,
      )
    }
    TypeLambda(parameters~, body~, loc~) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      TypeLambda(
        parameters=resolved_type_parameters,
        body=body.resolve_type(resolver, next_scope),
        loc~,
      )
    }
    Function(type_parameters~, parameters~, result~, effect~, loc~) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        type_parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      Function(
        type_parameters=resolved_type_parameters,
        parameters=parameters.map(fn(type_) {
          type_.resolve_type(resolver, next_scope)
        }),
        result=result.resolve_type(resolver, next_scope),
        effect=effect.resolve_effect_term(resolver, next_scope),
        loc~,
      )
    }
    Tuple(_) => self.resolve_tuple_type(resolver, scope)
    Grouped(type_~, ..) => type_.resolve_type(resolver, scope)
  }
}

///|
fn Resolver::resolve_module_qualified_type(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
  loc : SourceSpan,
) -> ResolvedType {
  let module_path_text = @module_interface.module_path_text(module_path)
  let resolved_name = ResolvedNominalName::Qualified({
    module_binding: module_path_text,
    name,
  })
  let full_name = resolved_name.display_text()
  guard self.resolve_authored_module_namespace(
      module_path_text,
      module_path.loc,
    )
    is Some(source) else {
    self.report(UnresolvedType(full_name), loc)
    return Unresolved(name=full_name, arguments=[], loc~)
  }
  match source.type_binding(name) {
    Some(binding) => {
      self.record_import_uses(binding.import_origins, loc)
      match binding.kind {
        NominalType(symbol~, ..) =>
          return Constructor(symbol~, name=resolved_name, loc~)
        TypeAlias(symbol~, ..) =>
          return Alias(
            symbol~,
            owner_module_path=Some(binding.owner_module_path),
            name=resolved_name,
            loc~,
          )
        EffectType(_) => ()
      }
    }
    None => ()
  }
  self.report(UnresolvedType(full_name), loc)
  Unresolved(name=full_name, arguments=[], loc~)
}

///|
fn Resolver::type_alias_binding(
  self : Resolver,
  name : String,
) -> TypeAliasBinding? {
  for index = self.type_aliases.length(); index > 0; index = index - 1 {
    let binding = self.type_aliases[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn primitive_type(name : String) -> @types.PrimitiveType? {
  match name {
    "Int" => Some(Int)
    "Double" => Some(Double)
    "Bool" => Some(Bool)
    "String" => Some(String)
    "Unit" => Some(Unit)
    _ => None
  }
}
