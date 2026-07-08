///|
priv struct FingerprintNominalTypeName {
  symbol : @symbol.TypeSymbolId
  name : String
}

///|
priv struct FingerprintTypeParameterName {
  symbol : @symbol.TypeParameterId
  name : String
  kind : @types.Kind
}

///|
priv struct FingerprintTypeContext {
  nominal_types : Array[FingerprintNominalTypeName]
  type_parameters : Array[FingerprintTypeParameterName]
}

///|
fn imported_environment_fingerprints(
  imported : @module_interface.ImportedEnvironment,
) -> Array[ImportedInterfaceFingerprint] {
  imported.modules.map(fn(interface) {
    {
      module_path_text: interface.module_path,
      fingerprint: interface_fingerprint(interface),
    }
  })
}

///|
fn module_fingerprint(
  interface : @module_interface.ModuleInterface,
  imported : Array[ImportedInterfaceFingerprint],
) -> CompilationFingerprint {
  fingerprint_hash(
    "lane-module-fingerprint-v1",
    module_fingerprint_payload(interface, imported),
  )
}

///|
fn module_fingerprint_payload(
  interface : @module_interface.ModuleInterface,
  imported : Array[ImportedInterfaceFingerprint],
) -> String {
  let imports = imported
    .map(fn(entry) { "\{entry.module_path_text}=\{entry.fingerprint.value}" })
    .join(";")
  "\{interface_fingerprint(interface).value}|imports:\{imports}"
}

///|
fn module_object_fingerprint(
  module_fingerprint : CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @elaborate.BuslaneExternalMap,
  entries : Array[@elaborate.BuslaneEntry],
  exports : Array[@elaborate.BuslaneModuleExport],
  imports : Array[ModuleImportedReference],
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint],
) -> CompilationFingerprint {
  fingerprint_hash_bytes(
    "lane-object-fingerprint-v1",
    module_object_fingerprint_payload_bytes(
      module_fingerprint, metadata, terms, externals, entries, exports, imports,
      imported_interface_fingerprints,
    ),
  )
}

///|
fn module_object_fingerprint_payload_bytes(
  module_fingerprint : CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @elaborate.BuslaneExternalMap,
  entries : Array[@elaborate.BuslaneEntry],
  exports : Array[@elaborate.BuslaneModuleExport],
  imports : Array[ModuleImportedReference],
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint],
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_compilation_fingerprint(module_fingerprint)
  writer.write_buslane_program_section({ metadata, terms })
  writer.write_externals(externals)
  writer.write_entries(entries)
  writer.write_exports(exports)
  writer.write_imports(imports)
  writer.write_imported_interface_fingerprints(imported_interface_fingerprints)
  writer.to_bytes()
}

///|
fn interface_fingerprint(
  interface : @module_interface.ModuleInterface,
) -> CompilationFingerprint {
  fingerprint_hash(
    "lane-interface-fingerprint-v1",
    interface_fingerprint_payload(interface),
  )
}

///|
fn interface_fingerprint_payload(
  interface : @module_interface.ModuleInterface,
) -> String {
  let context = fingerprint_type_context(interface)
  let type_fingerprints = interface.types
    .map(fn(type_) { interface_type_fingerprint(context, type_) })
    .join(",")
  let alias_fingerprints = interface.type_aliases
    .map(fn(type_alias) { interface_alias_fingerprint(context, type_alias) })
    .join(",")
  let effect_fingerprints = interface.effects
    .map(fn(effect) { interface_effect_fingerprint(context, effect) })
    .join(",")
  let value_fingerprints = interface.values
    .map(fn(value) { interface_value_fingerprint(context, value) })
    .join(",")
  let hint_fingerprints = interface.optimization_hints
    .map(fn(hint) { hint.name })
    .join(",")
  "\{interface.module_path}|types:\{type_fingerprints}|aliases:\{alias_fingerprints}|effects:\{effect_fingerprints}|values:\{value_fingerprints}|hints:\{hint_fingerprints}"
}

///|
fn fingerprint_hash(tag : String, payload : String) -> CompilationFingerprint {
  {
    value: "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode("\{tag}\n\{payload}")))}",
  }
}

///|
fn fingerprint_hash_bytes(
  tag : String,
  payload : Bytes,
) -> CompilationFingerprint {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_string(tag)
  writer.write_raw_bytes(payload)
  {
    value: "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(writer.to_bytes()))}",
  }
}

///|
fn fingerprint_type_context(
  interface : @module_interface.ModuleInterface,
) -> FingerprintTypeContext {
  let nominal_types = []
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        nominal_types.push({
          symbol: declaration.symbol,
          name: declaration.name,
        })
      Enum(declaration) =>
        nominal_types.push({
          symbol: declaration.symbol,
          name: declaration.name,
        })
    }
  }
  { nominal_types, type_parameters: [] }
}

///|
fn interface_type_fingerprint(
  context : FingerprintTypeContext,
  type_ : @module_interface.ModuleInterfaceType,
) -> String {
  match type_ {
    Struct(declaration) => {
      let context = context.with_type_parameters(declaration.type_parameters)
      let context = context.with_type_parameters(
        declaration.type_members.map(fn(type_member) {
          type_member.type_parameter
        }),
      )
      let type_parameters = declaration.type_parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let type_members = declaration.type_members
        .map(interface_type_member_fingerprint)
        .join(",")
      let fields = declaration.fields
        .map(fn(field) { interface_field_fingerprint(context, field) })
        .join(",")
      "struct \{declaration.name}[\{type_parameters}]{\{type_members}|\{fields}}"
    }
    Enum(declaration) => {
      let context = context.with_type_parameters(declaration.type_parameters)
      let type_parameters = declaration.type_parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let variants = declaration.variants
        .map(fn(variant) { interface_variant_fingerprint(context, variant) })
        .join(",")
      "enum \{declaration.name}[\{type_parameters}]{\{variants}}"
    }
  }
}

///|
fn interface_type_member_fingerprint(
  type_member : @module_interface.ModuleInterfaceTypeMember,
) -> String {
  "\{type_member.name}:\{kind_fingerprint(type_member.kind)}#\{type_member.index}"
}

///|
fn interface_field_fingerprint(
  context : FingerprintTypeContext,
  field : @module_interface.ModuleInterfaceField,
) -> String {
  let offered = if field.is_offered { ":offer" } else { "" }
  "\{field.name}:\{context.type_fingerprint(field.type_)}#\{field.index}\{offered}"
}

///|
fn interface_variant_fingerprint(
  context : FingerprintTypeContext,
  variant : @module_interface.ModuleInterfaceVariant,
) -> String {
  let context = context.with_type_parameters(variant.type_parameters)
  let type_parameters = variant.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let payload = variant.payload
    .map(fn(type_) { context.type_fingerprint(type_) })
    .join(",")
  "\{variant.name}[\{type_parameters}](\{payload})#\{variant.index}"
}

///|
fn interface_alias_fingerprint(
  context : FingerprintTypeContext,
  type_alias : @module_interface.ModuleInterfaceTypeAlias,
) -> String {
  let type_parameters = type_alias.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  "\{type_alias.name}[\{type_parameters}]:\{kind_fingerprint(type_alias.kind)}=\{context.type_alias_body_fingerprint(type_alias.body)}"
}

///|
fn FingerprintTypeContext::type_alias_body_fingerprint(
  self : FingerprintTypeContext,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> String {
  match body {
    TypeBody(type_) => "type:" + self.type_fingerprint(type_)
    EffectBody(effect) => "effect:" + self.effect_fingerprint(effect)
  }
}

///|
fn interface_effect_fingerprint(
  context : FingerprintTypeContext,
  effect : @module_interface.ModuleInterfaceEffect,
) -> String {
  let context = context.with_type_parameters(effect.type_parameters)
  let type_parameters = effect.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let operations = effect.operations
    .map(fn(operation) { interface_operation_fingerprint(context, operation) })
    .join(",")
  "effect \{effect.name}[\{type_parameters}]{\{operations}}"
}

///|
fn interface_operation_fingerprint(
  context : FingerprintTypeContext,
  operation : @module_interface.ModuleInterfaceOperation,
) -> String {
  let context = context.with_type_parameters(operation.type_parameters)
  let type_parameters = operation.type_parameters
    .map(type_parameter_fingerprint)
    .join(",")
  let payload = operation.payload
    .map(fn(type_) { context.type_fingerprint(type_) })
    .join(",")
  let result = context.type_fingerprint(operation.result)
  "\{operation.name}[\{type_parameters}](\{payload})->\{result}#\{operation.index}"
}

///|
fn interface_value_fingerprint(
  context : FingerprintTypeContext,
  value : @module_interface.ModuleInterfaceValue,
) -> String {
  let kind = module_value_kind_fingerprint(value.kind)
  let type_ = context.type_fingerprint(value.type_)
  let parameters = interface_value_parameters_fingerprint(
    context,
    value.parameters,
  )
  "\{value.name}:\{kind}:\{type_}(\{parameters})"
}

///|
fn interface_value_parameters_fingerprint(
  context : FingerprintTypeContext,
  parameters : Array[@module_interface.ModuleInterfaceValueParameter]?,
) -> String {
  match parameters {
    Some(parameters) =>
      parameters
      .map(fn(parameter) {
        let auto = if parameter.is_auto { ":auto" } else { "" }
        let offered = if parameter.is_offered { ":offer" } else { "" }
        "\{parameter.name}:\{context.type_fingerprint(parameter.type_)}\{auto}\{offered}"
      })
      .join(",")
    None => ""
  }
}

///|
fn module_value_kind_fingerprint(
  kind : @module_interface.ModuleInterfaceValueKind,
) -> String {
  match kind {
    Function => "function"
    Let => "let"
    Offer => "offer"
  }
}

///|
fn type_parameter_fingerprint(parameter : @types.TypeParameter) -> String {
  kind_fingerprint(parameter.kind)
}

///|
fn FingerprintTypeContext::with_type_parameters(
  self : FingerprintTypeContext,
  parameters : Array[@types.TypeParameter],
) -> FingerprintTypeContext {
  let type_parameters = self.type_parameters.copy()
  for parameter in parameters {
    type_parameters.push({
      symbol: parameter.id,
      name: parameter.name,
      kind: parameter.kind,
    })
  }
  { nominal_types: self.nominal_types, type_parameters }
}

///|
fn FingerprintTypeContext::type_fingerprint(
  self : FingerprintTypeContext,
  type_ : @types.Type,
) -> String {
  match type_ {
    Error => "<error>"
    Primitive(primitive) => @prettyprinter.render(primitive.pretty(), width=100)
    Constructor(symbol) => self.type_name(symbol)
    Apply(callee, arguments) => {
      let callee_fingerprint = self.type_fingerprint(callee)
      let arguments = arguments
        .map(fn(argument) { self.generic_argument_fingerprint(argument) })
        .join(",")
      "\{callee_fingerprint}[\{arguments}]"
    }
    TypeLambda(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      let parameter_fingerprints = parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let body_fingerprint = context.type_fingerprint(body)
      "type[\{parameter_fingerprints}]=>\{body_fingerprint}"
    }
    Parameter(symbol) => self.type_parameter_name(symbol)
    Function(parameters, result, effect) => {
      let parameters = parameters
        .map(fn(parameter) { self.type_fingerprint(parameter) })
        .join(",")
      let result = self.type_fingerprint(result)
      let effect = self.effect_fingerprint(effect)
      "(\{parameters})->\{result}!\{effect}"
    }
    Forall(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      let parameter_fingerprints = parameters
        .map(type_parameter_fingerprint)
        .join(",")
      let body_fingerprint = context.type_fingerprint(body)
      "forall[\{parameter_fingerprints}].\{body_fingerprint}"
    }
  }
}

///|
fn FingerprintTypeContext::effect_fingerprint(
  self : FingerprintTypeContext,
  effect : @types.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Singleton(symbol, arguments) => {
      let arguments = arguments
        .map(fn(argument) { self.generic_argument_fingerprint(argument) })
        .join(",")
      "\{@prettyprinter.render(symbol.pretty(), width=100)}[\{arguments}]"
    }
    Parameter(symbol) => self.type_parameter_name(symbol)
    Union(effects) =>
      "{\{effects.map(fn(effect) { self.effect_fingerprint(effect) }).join(",")}}"
  }
}

///|
fn FingerprintTypeContext::generic_argument_fingerprint(
  self : FingerprintTypeContext,
  argument : @types.GenericArgument,
) -> String {
  match argument {
    TypeArgument(type_) => self.type_fingerprint(type_)
    EffectArgument(effect) => self.effect_fingerprint(effect)
  }
}

///|
fn FingerprintTypeContext::type_name(
  self : FingerprintTypeContext,
  symbol : @symbol.TypeSymbolId,
) -> String {
  for item in self.nominal_types {
    if item.symbol == symbol {
      return item.name
    }
  }
  @prettyprinter.render(symbol.pretty(), width=100)
}

///|
fn FingerprintTypeContext::type_parameter_name(
  self : FingerprintTypeContext,
  symbol : @symbol.TypeParameterId,
) -> String {
  for item in self.type_parameters {
    if item.symbol == symbol {
      return "\{item.name}:\{kind_fingerprint(item.kind)}"
    }
  }
  @prettyprinter.render(symbol.pretty(), width=100)
}

///|
fn kind_fingerprint(kind : @types.Kind) -> String {
  @prettyprinter.render(kind.pretty(), width=100)
}

///|
