///|
using @prettyprinter {separate, text}

///|
priv struct ArtifactTypeName {
  type_symbol : @symbol.TypeSymbolId
  type_name : String
}

///|
priv struct ArtifactEffectName {
  effect_symbol : @symbol.EffectSymbolId
  effect_name : String
}

///|
priv struct ArtifactTypeParameterName {
  parameter_id : @symbol.TypeParameterId
  parameter_name : String
}

///|
priv struct ArtifactInspectContext {
  types : Array[ArtifactTypeName]
  effects : Array[ArtifactEffectName]
  type_parameters : Array[ArtifactTypeParameterName]
}

///|
fn module_interface_artifact_to_inspect_text(
  artifact : ModuleInterfaceArtifact,
) -> String {
  @prettyprinter.render(artifact, width=100) + "\n"
}

///|
fn module_object_artifact_to_inspect_text(
  artifact : ModuleObjectArtifact,
) -> String {
  @prettyprinter.render(artifact, width=100) + "\n"
}

///|
fn linked_program_artifact_to_inspect_text(
  artifact : LinkedProgramArtifact,
) -> String {
  @prettyprinter.render(artifact, width=100) + "\n"
}

///|
pub impl @prettyprinter.Pretty for ModuleInterfaceArtifact with fn pretty(
  artifact : ModuleInterfaceArtifact,
) -> Document {
  separate(@prettyprinter.hardline + @prettyprinter.hardline, [
    artifact_header_doc(
      "interface",
      artifact.schema_version,
      artifact.module_path_text,
      artifact.interface_fingerprint,
      artifact.module_fingerprint,
      None,
    ),
    imported_fingerprints_doc(artifact.imported_interface_fingerprints),
    interface_summary_doc(artifact.interface),
  ])
}

///|
pub impl @prettyprinter.Pretty for ModuleObjectArtifact with fn pretty(
  artifact : ModuleObjectArtifact,
) -> Document {
  separate(@prettyprinter.hardline + @prettyprinter.hardline, [
    artifact_header_doc(
      "object",
      artifact.schema_version,
      artifact.module_path_text,
      artifact.interface_fingerprint,
      artifact.module_fingerprint,
      Some(artifact.object_fingerprint),
    ),
    imported_fingerprints_doc(artifact.imported_interface_fingerprints),
    interface_summary_doc(artifact.interface),
    object_summary_doc(artifact),
  ])
}

///|
pub impl @prettyprinter.Pretty for LinkedProgramArtifact with fn pretty(
  artifact : LinkedProgramArtifact,
) -> Document {
  let buslane = BuslaneInspectContext::{ metadata: artifact.program.metadata }
  let runtime_context = ArtifactInspectContext::from_runtime_effect_operations(
    artifact.runtime_effect_operations,
  )
  separate(@prettyprinter.hardline + @prettyprinter.hardline, [
    linked_program_header_doc(artifact),
    section_doc(
      "modules:",
      artifact.module_path_texts.map(fn(module_) { text(module_) }),
    ),
    section_doc(
      "public entries:",
      artifact.entries.map(fn(entry) { text(buslane.entry_text(entry)) }),
    ),
    section_doc(
      "externals:",
      artifact.externals.builtins.map(fn(external) {
        text(buslane.external_text(external))
      }),
    ),
    section_doc(
      "runtime effects:",
      artifact.runtime_effect_operations.map(fn(operation) {
        text(runtime_context.runtime_effect_operation_text(operation))
      }),
    ),
    buslane_program_doc(artifact.program.metadata, artifact.program.terms),
  ])
}

///|
fn artifact_header_doc(
  kind : String,
  schema_version : Int,
  module_path_text : String,
  interface_fingerprint : CompilationFingerprint,
  module_fingerprint : CompilationFingerprint,
  object_fingerprint : CompilationFingerprint?,
) -> Document {
  let fields = [
    text("Lane \{kind} artifact"),
    text("module: \{module_path_text}"),
    text("schema: \{schema_version}"),
    text("interface fingerprint: \{interface_fingerprint.value}"),
    text("module fingerprint: \{module_fingerprint.value}"),
  ]
  if object_fingerprint is Some(fingerprint) {
    fields.push(text("object fingerprint: \{fingerprint.value}"))
  }
  separate(@prettyprinter.hardline, fields)
}

///|
fn linked_program_header_doc(artifact : LinkedProgramArtifact) -> Document {
  separate(@prettyprinter.hardline, [
    text("Lane program artifact"),
    text("schema: \{artifact.schema_version}"),
  ])
}

///|
fn imported_fingerprints_doc(
  fingerprints : Array[ImportedInterfaceFingerprint],
) -> Document {
  section_doc(
    "imported interfaces:",
    fingerprints.map(fn(fingerprint) {
      text("\{fingerprint.module_path_text}: \{fingerprint.fingerprint.value}")
    }),
  )
}

///|
fn interface_summary_doc(
  interface : @module_interface.ModuleInterface,
) -> Document {
  let context = ArtifactInspectContext::from_interface(interface)
  text("interface \{interface.module_path}:") +
  @prettyprinter.hardline +
  separate(@prettyprinter.hardline, [
    section_doc(
      "types:",
      interface.types.map(fn(type_) { text(context.interface_type_text(type_)) }),
    ),
    section_doc(
      "effects:",
      interface.effects.map(fn(effect) {
        text(context.interface_effect_text(effect))
      }),
    ),
    section_doc(
      "type aliases:",
      interface.type_aliases.map(fn(alias_) {
        text(context.interface_type_alias_text(alias_))
      }),
    ),
    section_doc(
      "values:",
      interface.values.map(fn(value) {
        text(context.interface_value_text(value))
      }),
    ),
  ])
}

///|
fn object_summary_doc(artifact : ModuleObjectArtifact) -> Document {
  let buslane = BuslaneInspectContext::{ metadata: artifact.metadata }
  text("object:") +
  @prettyprinter.hardline +
  separate(@prettyprinter.hardline, [
    section_doc(
      "imports:",
      artifact.imports.map(fn(import_) { text(import_reference_text(import_)) }),
    ),
    section_doc(
      "exports:",
      artifact.exports.map(fn(export_) { text(export_text(export_)) }),
    ),
    section_doc(
      "public entries:",
      artifact.entries.map(fn(entry) { text(buslane.entry_text(entry)) }),
    ),
    section_doc(
      "externals:",
      artifact.externals.builtins.map(fn(external) {
        text(buslane.external_text(external))
      }),
    ),
    buslane_program_doc(artifact.metadata, artifact.terms),
  ])
}

///|
fn buslane_program_doc(
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
) -> Document {
  let program_text = @prettyprinter.render(
    @buslane.Program::{ metadata, terms },
    width=100,
  )
  text("buslane:") +
  @prettyprinter.hardline +
  indented_lines_doc(
    program_text.split("\n").map(fn(line) { text(line.to_owned()) }).collect(),
  )
}

///|
fn section_doc(title : String, items : Array[Document]) -> Document {
  text(title) +
  @prettyprinter.hardline +
  (if items.is_empty() { text("  (none)") } else { indented_lines_doc(items) })
}

///|
fn indented_lines_doc(items : Array[Document]) -> Document {
  separate(@prettyprinter.hardline, items.map(fn(item) { text("  ") + item }))
}

///|
fn ArtifactInspectContext::from_interface(
  interface : @module_interface.ModuleInterface,
) -> ArtifactInspectContext {
  let context = ArtifactInspectContext::{
    types: [],
    effects: [],
    type_parameters: [],
  }
  for type_ in interface.types {
    match type_ {
      Struct(declaration) => {
        context.types.push({
          type_symbol: declaration.symbol,
          type_name: declaration.name,
        })
        context.add_type_parameters(declaration.type_parameters)
        for member_ in declaration.type_members {
          context.type_parameters.push({
            parameter_id: member_.type_parameter.id,
            parameter_name: member_.name,
          })
        }
      }
      Enum(declaration) => {
        context.types.push({
          type_symbol: declaration.symbol,
          type_name: declaration.name,
        })
        context.add_type_parameters(declaration.type_parameters)
        for variant in declaration.variants {
          context.add_type_parameters(variant.type_parameters)
        }
      }
    }
  }
  for effect in interface.effects {
    context.effects.push({
      effect_symbol: effect.symbol,
      effect_name: effect.name,
    })
    context.add_type_parameters(effect.type_parameters)
    for operation in effect.operations {
      context.add_type_parameters(operation.type_parameters)
    }
  }
  for alias_ in interface.type_aliases {
    context.add_type_parameters(alias_.type_parameters)
    context.add_type_parameters_from_type_alias_body(alias_.body)
  }
  for value in interface.values {
    context.add_type_parameters_from_type(value.type_)
    if value.parameters is Some(parameters) {
      for parameter in parameters {
        context.add_type_parameters_from_type(parameter.type_)
      }
    }
  }
  context
}

///|
fn ArtifactInspectContext::from_runtime_effect_operations(
  operations : Array[LinkedRuntimeEffectOperation],
) -> ArtifactInspectContext {
  let context = ArtifactInspectContext::{
    types: [],
    effects: [],
    type_parameters: [],
  }
  for operation in operations {
    for payload in operation.payload {
      context.add_type_parameters_from_type(payload)
    }
    context.add_type_parameters_from_type(operation.result)
  }
  context
}

///|
fn ArtifactInspectContext::runtime_effect_operation_text(
  self : ArtifactInspectContext,
  operation : LinkedRuntimeEffectOperation,
) -> String {
  let payload = operation.payload
    .map(fn(type_) { self.type_text(type_) })
    .join(", ")
  "\{operation.module_path_text}.\{operation.effect_name}::\{operation.operation_name}(\{payload}) -> \{self.type_text(operation.result)} => operation#\{operation.operation.index}"
}

///|
fn ArtifactInspectContext::add_type_parameters(
  self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
) -> Unit {
  for parameter in parameters {
    self.type_parameters.push({
      parameter_id: parameter.id,
      parameter_name: parameter.name,
    })
  }
}

///|
fn ArtifactInspectContext::add_type_parameters_from_type(
  self : ArtifactInspectContext,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Error | Primitive(_) | Constructor(_) => ()
    Apply(callee, arguments) => {
      self.add_type_parameters_from_type(callee)
      for argument in arguments {
        self.add_type_parameters_from_type(argument)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      self.add_type_parameters(parameters)
      self.add_type_parameters_from_type(body)
    }
    Parameter(_) => ()
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.add_type_parameters_from_type(parameter)
      }
      self.add_type_parameters_from_type(result)
      self.add_type_parameters_from_effect(effect)
    }
  }
}

///|
fn ArtifactInspectContext::add_type_parameters_from_effect(
  self : ArtifactInspectContext,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty => ()
    Singleton(_, arguments) =>
      for argument in arguments {
        self.add_type_parameters_from_type(argument)
      }
    Parameter(_) => ()
    Union(effects) =>
      for effect in effects {
        self.add_type_parameters_from_effect(effect)
      }
  }
}

///|
fn ArtifactInspectContext::with_type_parameters(
  self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
) -> ArtifactInspectContext {
  let type_parameters = self.type_parameters.copy()
  for parameter in parameters {
    type_parameters.push({
      parameter_id: parameter.id,
      parameter_name: parameter.name,
    })
  }
  { types: self.types, effects: self.effects, type_parameters }
}

///|
fn ArtifactInspectContext::interface_type_text(
  self : ArtifactInspectContext,
  type_ : @module_interface.ModuleInterfaceType,
) -> String {
  match type_ {
    Struct(declaration) => self.struct_text(declaration)
    Enum(declaration) => self.enum_text(declaration)
  }
}

///|
fn ArtifactInspectContext::struct_text(
  self : ArtifactInspectContext,
  declaration : @module_interface.ModuleInterfaceStruct,
) -> String {
  let header = "pub struct \{declaration.name}\{self.type_parameters_suffix(declaration.type_parameters)}"
  let members = declaration.type_members.map(fn(member_) {
    "type \{member_.name} : \{self.kind_text(member_.kind)}"
  })
  let fields = declaration.fields.map(fn(field) {
    let prefix = if field.is_offered { "offer " } else { "" }
    "\{prefix}\{field.name} : \{self.type_text(field.type_)}"
  })
  let body = (members + fields).join("; ")
  if body.is_empty() {
    "\{header} {}"
  } else {
    "\{header} { \{body} }"
  }
}

///|
fn ArtifactInspectContext::enum_text(
  self : ArtifactInspectContext,
  declaration : @module_interface.ModuleInterfaceEnum,
) -> String {
  let variants = declaration.variants.map(fn(variant) {
    self.variant_text(variant)
  })
  "pub enum \{declaration.name}\{self.type_parameters_suffix(declaration.type_parameters)} { \{variants.join("; ")} }"
}

///|
fn ArtifactInspectContext::variant_text(
  self : ArtifactInspectContext,
  variant : @module_interface.ModuleInterfaceVariant,
) -> String {
  let type_parameters = self.type_parameters_suffix(variant.type_parameters)
  let payload = self.type_arguments_text(variant.payload)
  "\{variant.name}\{type_parameters}\{payload}"
}

///|
fn ArtifactInspectContext::interface_effect_text(
  self : ArtifactInspectContext,
  effect : @module_interface.ModuleInterfaceEffect,
) -> String {
  let operations = effect.operations.map(fn(operation) {
    self.operation_text(operation)
  })
  "pub effect \{effect.name}\{self.type_parameters_suffix(effect.type_parameters)} { \{operations.join("; ")} }"
}

///|
fn ArtifactInspectContext::operation_text(
  self : ArtifactInspectContext,
  operation : @module_interface.ModuleInterfaceOperation,
) -> String {
  let parameters = self.type_parameters_suffix(operation.type_parameters)
  let payload = self.type_arguments_text(operation.payload)
  "\{operation.name}\{parameters}\{payload} -> \{self.type_text(operation.result)}"
}

///|
fn ArtifactInspectContext::interface_type_alias_text(
  self : ArtifactInspectContext,
  alias_ : @module_interface.ModuleInterfaceTypeAlias,
) -> String {
  "pub type \{alias_.name}\{self.type_parameters_text(alias_.type_parameters)} : \{self.kind_text(alias_.kind)} = \{self.type_alias_body_text(alias_.body)}"
}

///|
fn ArtifactInspectContext::type_alias_body_text(
  self : ArtifactInspectContext,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> String {
  match body {
    TypeBody(type_) => self.type_text(type_)
    EffectBody(effect) => self.effect_text(effect)
  }
}

///|
fn ArtifactInspectContext::add_type_parameters_from_type_alias_body(
  self : ArtifactInspectContext,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> Unit {
  match body {
    TypeBody(type_) => self.add_type_parameters_from_type(type_)
    EffectBody(effect) => self.add_type_parameters_from_effect(effect)
  }
}

///|
fn ArtifactInspectContext::interface_value_text(
  self : ArtifactInspectContext,
  value : @module_interface.ModuleInterfaceValue,
) -> String {
  match value.kind {
    Function =>
      if value.parameters is Some(parameters) {
        let parameter_text = parameters
          .map(fn(parameter) { self.value_parameter_text(parameter) })
          .join(", ")
        "pub fn \{value.name}(\{parameter_text}) : \{self.type_text(value.type_)}"
      } else {
        "pub fn \{value.name} : \{self.type_text(value.type_)}"
      }
    Let => "pub let \{value.name} : \{self.type_text(value.type_)}"
    Offer => "pub offer \{value.name} : \{self.type_text(value.type_)}"
  }
}

///|
fn ArtifactInspectContext::value_parameter_text(
  self : ArtifactInspectContext,
  parameter : @module_interface.ModuleInterfaceValueParameter,
) -> String {
  let prefix = if parameter.is_auto {
    "auto "
  } else if parameter.is_offered {
    "offer "
  } else {
    ""
  }
  "\{prefix}\{parameter.name} : \{self.type_text(parameter.type_)}"
}

///|
fn ArtifactInspectContext::type_text(
  self : ArtifactInspectContext,
  type_ : @types.Type,
) -> String {
  match type_ {
    Error => "<error>"
    Primitive(primitive) => lane_primitive_text(primitive)
    Constructor(symbol) => self.type_symbol_text(symbol)
    Apply(callee, arguments) =>
      "\{self.type_text(callee)}[\{arguments.map(fn(argument) { self.type_text(argument) }).join(", ")}]"
    TypeLambda(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      "type [\{context.type_parameter_bindings_text(parameters)}] => \{context.type_text(body)}"
    }
    Parameter(id) => self.type_parameter_text(id)
    Function(parameters, result, effect) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_text(parameter) })
        .join(", ")
      let result_text = self.type_text(result)
      let effect_text = self.effect_text(effect)
      if effect_text == "{}" {
        "(\{parameter_text}) -> \{result_text}"
      } else {
        "(\{parameter_text}) -> \{result_text} ! \{effect_text}"
      }
    }
    Forall(parameters, body) => {
      let context = self.with_type_parameters(parameters)
      "forall [\{context.type_parameter_bindings_text(parameters)}]. \{context.type_text(body)}"
    }
  }
}

///|
fn ArtifactInspectContext::effect_text(
  self : ArtifactInspectContext,
  effect : @types.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Singleton(symbol, arguments) =>
      if arguments.is_empty() {
        self.effect_symbol_text(symbol)
      } else {
        "\{self.effect_symbol_text(symbol)}[\{arguments.map(fn(argument) { self.type_text(argument) }).join(", ")}]"
      }
    Parameter(id) => self.type_parameter_text(id)
    Union(effects) =>
      "{ \{effects.map(fn(effect) { self.effect_text(effect) }).join(", ")} }"
  }
}

///|
fn ArtifactInspectContext::type_parameters_suffix(
  self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
) -> String {
  if parameters.is_empty() {
    ""
  } else {
    "[\{self.type_parameter_bindings_text(parameters)}]"
  }
}

///|
fn ArtifactInspectContext::type_parameter_bindings_text(
  self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
) -> String {
  parameters
  .map(fn(parameter) { "\{parameter.name} : \{self.kind_text(parameter.kind)}" })
  .join(", ")
}

///|
fn ArtifactInspectContext::type_parameters_text(
  self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
) -> String {
  if parameters.is_empty() {
    ""
  } else {
    "[\{self.type_parameter_bindings_text(parameters)}]"
  }
}

///|
fn ArtifactInspectContext::type_arguments_text(
  self : ArtifactInspectContext,
  arguments : Array[@types.Type],
) -> String {
  if arguments.is_empty() {
    "()"
  } else {
    "(\{arguments.map(fn(argument) { self.type_text(argument) }).join(", ")})"
  }
}

///|
fn ArtifactInspectContext::kind_text(
  self : ArtifactInspectContext,
  kind : @types.Kind,
) -> String {
  match kind {
    Type => "Type"
    Effect => "Effect"
    Function(parameters, result) =>
      "[\{parameters.map(fn(parameter) { self.kind_text(parameter) }).join(", ")}] -> \{self.kind_text(result)}"
  }
}

///|
fn ArtifactInspectContext::type_symbol_text(
  self : ArtifactInspectContext,
  symbol : @symbol.TypeSymbolId,
) -> String {
  for item in self.types {
    if item.type_symbol == symbol {
      return item.type_name
    }
  }
  "type#\{symbol.index}"
}

///|
fn ArtifactInspectContext::effect_symbol_text(
  self : ArtifactInspectContext,
  symbol : @symbol.EffectSymbolId,
) -> String {
  for item in self.effects {
    if item.effect_symbol == symbol {
      return item.effect_name
    }
  }
  "effect#\{symbol.index}"
}

///|
fn ArtifactInspectContext::type_parameter_text(
  self : ArtifactInspectContext,
  id : @symbol.TypeParameterId,
) -> String {
  for item in self.type_parameters {
    if item.parameter_id == id {
      return item.parameter_name
    }
  }
  "tparam#\{id.index}"
}

///|
fn lane_primitive_text(primitive : @types.PrimitiveType) -> String {
  match primitive {
    Int => "Int"
    Bool => "Bool"
    String => "String"
    Unit => "Unit"
  }
}

///|
priv struct BuslaneInspectContext {
  metadata : @buslane.MetadataRegistry
}

///|
fn BuslaneInspectContext::entry_text(
  self : BuslaneInspectContext,
  entry : @elaborate.BuslaneEntry,
) -> String {
  "\{entry.name} : \{self.type_text(entry.type_)}"
}

///|
fn BuslaneInspectContext::external_text(
  self : BuslaneInspectContext,
  external : @elaborate.BuslaneBuiltinExternal,
) -> String {
  "\{external.name} : \{self.type_text(external.type_)}"
}

///|
fn BuslaneInspectContext::type_text(
  self : BuslaneInspectContext,
  type_ : @buslane.Type,
) -> String {
  match type_ {
    Primitive(primitive) => buslane_primitive_text(primitive)
    Parameter(id) => self.type_parameter_text(id)
    Constructor(id) => self.type_id_text(id)
    Apply(callee, arguments) =>
      "\{self.type_text(callee)}[\{arguments.map(fn(argument) { self.type_text(argument) }).join(", ")}]"
    TypeLambda(parameters, body) =>
      "type [\{self.type_parameter_bindings_text(parameters)}] => \{self.type_text(body)}"
    Function(parameters, result, effect) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_text(parameter) })
        .join(", ")
      let result_text = self.type_text(result)
      let effect_text = self.effect_text(effect)
      if effect_text == "{}" {
        "(\{parameter_text}) -> \{result_text}"
      } else {
        "(\{parameter_text}) -> \{result_text} ! \{effect_text}"
      }
    }
    Forall(parameters, body) =>
      "forall [\{self.type_parameter_bindings_text(parameters)}]. \{self.type_text(body)}"
  }
}

///|
fn BuslaneInspectContext::effect_text(
  self : BuslaneInspectContext,
  effect : @buslane.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Singleton(id, arguments) =>
      if arguments.is_empty() {
        self.effect_id_text(id)
      } else {
        "\{self.effect_id_text(id)}[\{arguments.map(fn(argument) { self.type_text(argument) }).join(", ")}]"
      }
    Parameter(id) => self.type_parameter_text(id)
    Union(effects) =>
      "{ \{effects.map(fn(effect) { self.effect_text(effect) }).join(", ")} }"
  }
}

///|
fn BuslaneInspectContext::type_parameter_bindings_text(
  self : BuslaneInspectContext,
  parameters : Array[@buslane.TypeParameterId],
) -> String {
  parameters
  .map(fn(parameter) {
    match self.metadata.type_parameter_info(parameter) {
      Some(info) => "\{info.name.occurrence} : \{buslane_kind_text(info.kind)}"
      None => self.type_parameter_text(parameter)
    }
  })
  .join(", ")
}

///|
fn BuslaneInspectContext::type_id_text(
  self : BuslaneInspectContext,
  id : @buslane.TypeId,
) -> String {
  match self.metadata.type_info(id) {
    Some(info) => info.name.occurrence
    None => "type#\{id.index}"
  }
}

///|
fn BuslaneInspectContext::type_parameter_text(
  self : BuslaneInspectContext,
  id : @buslane.TypeParameterId,
) -> String {
  match self.metadata.type_parameter_info(id) {
    Some(info) => info.name.occurrence
    None => "tparam#\{id.index}"
  }
}

///|
fn BuslaneInspectContext::effect_id_text(
  self : BuslaneInspectContext,
  id : @buslane.EffectId,
) -> String {
  match self.metadata.effect_info(id) {
    Some(info) => info.name.occurrence
    None => "effect#\{id.index}"
  }
}

///|
fn buslane_primitive_text(primitive : @buslane.PrimitiveType) -> String {
  match primitive {
    Unit => "Unit"
    Bool => "Bool"
    Int => "Int"
    String => "String"
  }
}

///|
fn buslane_kind_text(kind : @buslane.Kind) -> String {
  match kind {
    Type => "Type"
    Effect => "Effect"
    Function(parameters, result) =>
      "[\{parameters.map(buslane_kind_text).join(", ")}] -> \{buslane_kind_text(result)}"
  }
}

///|
fn import_reference_text(import_ : ModuleImportedReference) -> String {
  "\{export_kind_text(import_.kind)} \{import_.module_path_text}::\{import_.name}"
}

///|
fn export_text(export_ : @elaborate.BuslaneModuleExport) -> String {
  "\{export_kind_text(export_.kind)} \{export_.name}"
}

///|
fn export_kind_text(kind : @elaborate.BuslaneModuleExportKind) -> String {
  match kind {
    Type => "type"
    DataConstructor => "data constructor"
    Effect => "effect"
    Operation => "operation"
    FieldSelector => "field selector"
    Value => "value"
  }
}
