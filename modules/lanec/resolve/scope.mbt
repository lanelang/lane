///|
priv struct ValueBinding {
  name : String
  reference : ResolvedValueReference
  type_ : ResolvedType?
  kind : ValueBindingKind
  source : ValueBindingSource
  import_origin : Int?
}

///|
priv enum ValueBindingKind {
  Plain
} derive(Eq)

///|
priv enum ValueBindingSource {
  CurrentSource
  ExternalSource(source_id~ : String)
  NoSource(origin~ : String)
}

///|
priv struct ResolveScope {
  values : Array[ValueBinding]
  type_parameters : Array[ResolvedTypeParameter]
}

///|
fn ResolveScope::copy(self : ResolveScope) -> ResolveScope {
  { values: self.values.copy(), type_parameters: self.type_parameters.copy() }
}

///|
fn ResolveScope::enter_scope(self : ResolveScope) -> ResolveScope {
  { values: self.values.copy(), type_parameters: self.type_parameters.copy() }
}

///|
fn ResolveScope::define_value(
  self : ResolveScope,
  name : String,
  symbol : ValueSymbolId,
  type_ : ResolvedType?,
) -> Unit {
  self.values.push({
    name,
    reference: Symbol(symbol),
    type_,
    kind: Plain,
    source: CurrentSource,
    import_origin: None,
  })
}

///|
fn ResolveScope::value_reference(
  self : ResolveScope,
  name : String,
) -> ResolvedValueReference {
  for index = self.values.length(); index > 0; index = index - 1 {
    let binding = self.values[index - 1]
    if binding.name == name {
      return binding.reference
    }
  }
  Unresolved(name)
}

///|
fn ResolveScope::value_type(
  self : ResolveScope,
  reference : ResolvedValueReference,
) -> ResolvedType? {
  match reference {
    Symbol(symbol) => {
      for index = self.values.length(); index > 0; index = index - 1 {
        let binding = self.values[index - 1]
        if binding.reference == Symbol(symbol) {
          return binding.type_
        }
      }
      None
    }
    _ => None
  }
}

///|
fn ResolveScope::value_import_origin(
  self : ResolveScope,
  reference : ResolvedValueReference,
) -> Int? {
  match reference {
    Symbol(_) =>
      for index = self.values.length(); index > 0; index = index - 1 {
        let binding = self.values[index - 1]
        if binding.reference == reference {
          return binding.import_origin
        }
      }
    _ => ()
  }
  None
}

///|
fn ResolveScope::type_parameter(
  self : ResolveScope,
  name : String,
) -> TypeParameterId? {
  self.type_parameter_info(name).map(fn(parameter) { parameter.symbol })
}

///|
fn ResolveScope::type_parameter_info(
  self : ResolveScope,
  name : String,
) -> ResolvedTypeParameter? {
  for index = self.type_parameters.length(); index > 0; index = index - 1 {
    let parameter = self.type_parameters[index - 1]
    if parameter.name == name {
      return Some(parameter)
    }
  }
  None
}
