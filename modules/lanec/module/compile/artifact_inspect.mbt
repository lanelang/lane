///|
using @prettyprinter {type Document, separate, text}

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
    object_summary_doc(artifact),
  ])
}

///|
pub impl @prettyprinter.Pretty for LinkedProgramArtifact with fn pretty(
  artifact : LinkedProgramArtifact,
) -> Document {
  let disassembly = @loisvm_bytecode.bytecode_image_to_disassembly(
      artifact.bytecode,
    )
    .split("\n")
    .map(StringView::to_owned)
    .collect()
  ignore(disassembly.pop())
  text(
    "Lane program artifact\nschema: \{artifact.schema_version}\n\n" +
    disassembly.join("\n"),
  )
}

///|
fn artifact_header_doc(
  kind : String,
  schema_version : Int,
  module_path_text : String,
  interface_fingerprint : @artifact_core.CompilationFingerprint,
  module_fingerprint : @artifact_core.CompilationFingerprint,
  object_fingerprint : @artifact_core.CompilationFingerprint?,
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
fn imported_fingerprints_doc(
  fingerprints : Array[@artifact_core.ImportedInterfaceFingerprint],
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
  let display = context.type_display_context()
  text("interface \{interface.module_path}:") +
  @prettyprinter.hardline +
  separate(@prettyprinter.hardline, [
    section_doc(
      "types:",
      interface.types.map(fn(type_) {
        text(context.interface_type_text(type_, display))
      }),
    ),
    section_doc(
      "effects:",
      interface.effects.map(fn(effect) {
        text(context.interface_effect_text(effect, display))
      }),
    ),
    section_doc(
      "type aliases:",
      interface.type_aliases.map(fn(alias_) {
        text(context.interface_type_alias_text(alias_, display))
      }),
    ),
    section_doc(
      "values:",
      interface.values.map(fn(value) {
        text(context.interface_value_text(value, display))
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
      "compiler intrinsics:",
      artifact.externals.builtins.map(fn(external) {
        text(buslane.intrinsic_text(external))
      }),
    ),
    section_doc(
      "runtime imports:",
      artifact.externals.runtime_imports.map(fn(import_) {
        text(buslane.runtime_import_text(import_))
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
  for reference in interface.type_references {
    context.types.push({
      type_symbol: reference.symbol,
      type_name: reference.name,
    })
  }
  for reference in interface.effect_references {
    context.effects.push({
      effect_symbol: reference.symbol,
      effect_name: reference.name,
    })
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
      External(declaration) =>
        context.types.push({
          type_symbol: declaration.symbol,
          type_name: declaration.name,
        })
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
fn ArtifactInspectContext::type_display_context(
  self : ArtifactInspectContext,
) -> @typecheck.TypeDisplayContext {
  @typecheck.TypeDisplayContext::from_names(
    self.types.map(fn(item) { (item.type_symbol, item.type_name) }),
    self.effects.map(fn(item) { (item.effect_symbol, item.effect_name) }),
    self.type_parameters.map(fn(item) {
      (item.parameter_id, item.parameter_name)
    }),
  )
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
        self.add_type_parameters_from_generic_argument(argument)
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
    Empty | Io => ()
    Singleton(_, arguments) =>
      for argument in arguments {
        self.add_type_parameters_from_generic_argument(argument)
      }
    Parameter(_) => ()
    Union(effects) =>
      for effect in effects {
        self.add_type_parameters_from_effect(effect)
      }
  }
}

///|
fn ArtifactInspectContext::add_type_parameters_from_generic_argument(
  self : ArtifactInspectContext,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.add_type_parameters_from_type(type_)
    EffectArgument(effect) => self.add_type_parameters_from_effect(effect)
  }
}

///|
fn ArtifactInspectContext::interface_type_text(
  self : ArtifactInspectContext,
  type_ : @module_interface.ModuleInterfaceType,
  display : @typecheck.TypeDisplayContext,
) -> String {
  match type_ {
    Struct(declaration) => self.struct_text(declaration, display)
    Enum(declaration) => self.enum_text(declaration, display)
    External(declaration) => "pub extern type \{declaration.name} : Type"
  }
}

///|
fn ArtifactInspectContext::struct_text(
  self : ArtifactInspectContext,
  declaration : @module_interface.ModuleInterfaceStruct,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let header = "pub struct \{declaration.name}\{self.type_parameters_suffix(declaration.type_parameters, display)}"
  let members = declaration.type_members.map(fn(member_) {
    "type \{member_.name} : \{display.kind_text(member_.kind)}"
  })
  let fields = declaration.fields.map(fn(field) {
    "\{field.name} : \{display.type_text(field.type_)}"
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
  display : @typecheck.TypeDisplayContext,
) -> String {
  let variants = declaration.variants.map(fn(variant) {
    self.variant_text(variant, display)
  })
  "pub enum \{declaration.name}\{self.type_parameters_suffix(declaration.type_parameters, display)} { \{variants.join("; ")} }"
}

///|
fn ArtifactInspectContext::variant_text(
  self : ArtifactInspectContext,
  variant : @module_interface.ModuleInterfaceVariant,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let type_parameters = self.type_parameters_suffix(
    variant.type_parameters,
    display,
  )
  let payload = self.type_arguments_text(variant.payload, display)
  "\{variant.name}\{type_parameters}\{payload}"
}

///|
fn ArtifactInspectContext::interface_effect_text(
  self : ArtifactInspectContext,
  effect : @module_interface.ModuleInterfaceEffect,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let operations = effect.operations.map(fn(operation) {
    self.operation_text(operation, display)
  })
  let header = if effect.flavor is External {
    "pub extern type \{effect.name}\{self.type_parameters_suffix(effect.type_parameters, display)} : Effect"
  } else {
    "pub effect \{effect.name}\{self.type_parameters_suffix(effect.type_parameters, display)}"
  }
  if effect.flavor is External {
    header
  } else {
    "\{header} { \{operations.join("; ")} }"
  }
}

///|
fn ArtifactInspectContext::operation_text(
  self : ArtifactInspectContext,
  operation : @module_interface.ModuleInterfaceOperation,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let parameters = self.type_parameters_suffix(
    operation.type_parameters,
    display,
  )
  let payload = self.type_arguments_text(operation.payload, display)
  "\{operation.name}\{parameters}\{payload} -> \{display.type_text(operation.result)}"
}

///|
fn ArtifactInspectContext::interface_type_alias_text(
  self : ArtifactInspectContext,
  alias_ : @module_interface.ModuleInterfaceTypeAlias,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "pub type \{alias_.name}\{self.type_parameters_suffix(alias_.type_parameters, display)} : \{display.kind_text(alias_.kind)} = \{self.type_alias_body_text(alias_.body, display)}"
}

///|
fn ArtifactInspectContext::type_alias_body_text(
  _self : ArtifactInspectContext,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
  display : @typecheck.TypeDisplayContext,
) -> String {
  match body {
    TypeBody(type_) => display.type_text(type_)
    EffectBody(effect) => display.effect_text(effect)
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
  display : @typecheck.TypeDisplayContext,
) -> String {
  let offered = if value.is_offered { "offer " } else { "" }
  let type_text = display.type_text_with_tuple_presentations(
    value.type_,
    value.tuple_presentations,
  )
  match value.kind {
    Function =>
      if value.parameters is Some(parameters) {
        let parameter_text = []
        for index, parameter in parameters {
          let parameter_type_text = display.type_text_with_tuple_presentations_at(
            parameter.type_,
            value.tuple_presentations,
            [FunctionParameter(index)],
          )
          parameter_text.push(
            self.value_parameter_text(parameter, parameter_type_text),
          )
        }
        "pub \{offered}fn \{value.name}(\{parameter_text.join(", ")}) : \{type_text}"
      } else {
        "pub \{offered}fn \{value.name} : \{type_text}"
      }
    Let =>
      if value.is_offered {
        "pub offer \{value.name} : \{type_text}"
      } else {
        "pub let \{value.name} : \{type_text}"
      }
  }
}

///|
fn ArtifactInspectContext::value_parameter_text(
  _self : ArtifactInspectContext,
  parameter : @module_interface.ModuleInterfaceValueParameter,
  type_text : String,
) -> String {
  let prefix = if parameter.is_auto {
    "auto "
  } else if parameter.is_offered {
    "offer "
  } else {
    ""
  }
  "\{prefix}\{parameter.name} : \{type_text}"
}

///|
fn ArtifactInspectContext::type_parameters_suffix(
  _self : ArtifactInspectContext,
  parameters : Array[@types.TypeParameter],
  display : @typecheck.TypeDisplayContext,
) -> String {
  if parameters.is_empty() {
    ""
  } else {
    "[\{parameters.map(fn(parameter) { display.type_parameter_binding_text(parameter) }).join(", ")}]"
  }
}

///|
fn ArtifactInspectContext::type_arguments_text(
  _self : ArtifactInspectContext,
  arguments : Array[@types.Type],
  display : @typecheck.TypeDisplayContext,
) -> String {
  if arguments.is_empty() {
    "()"
  } else {
    "(\{arguments.map(fn(argument) { display.type_text(argument) }).join(", ")})"
  }
}

///|
priv struct BuslaneInspectContext {
  metadata : @buslane.MetadataRegistry
}

///|
fn entry_display_name(entry : @buslane_lowering.BuslaneEntry) -> String {
  "\{entry.module_path_text}.\{entry.name}"
}

///|
fn BuslaneInspectContext::entry_text(
  self : BuslaneInspectContext,
  entry : @buslane_lowering.BuslaneEntry,
) -> String {
  "\{entry_display_name(entry)} : \{self.type_text(entry.type_)}"
}

///|
fn BuslaneInspectContext::intrinsic_text(
  self : BuslaneInspectContext,
  external : @buslane_lowering.BuslaneBuiltinExternal,
) -> String {
  "\{external.intrinsic.name()} : \{self.type_text(external.type_)}"
}

///|
fn BuslaneInspectContext::runtime_import_text(
  self : BuslaneInspectContext,
  import_ : @buslane_lowering.BuslaneRuntimeImport,
) -> String {
  "\{import_.symbol} : \{self.type_text(import_.type_)}"
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
      "\{self.type_text(callee)}[\{arguments.map(fn(argument) { self.generic_argument_text(argument) }).join(", ")}]"
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
    Io => "Io"
    Singleton(id, arguments) =>
      if arguments.is_empty() {
        self.effect_id_text(id)
      } else {
        "\{self.effect_id_text(id)}[\{arguments.map(fn(argument) { self.generic_argument_text(argument) }).join(", ")}]"
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
fn BuslaneInspectContext::generic_argument_text(
  self : BuslaneInspectContext,
  argument : @buslane.GenericArgument,
) -> String {
  match argument {
    TypeArgument(type_) => self.type_text(type_)
    EffectArgument(effect) => self.effect_text(effect)
  }
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
    Double => "Double"
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
fn import_reference_text(
  import_ : @artifact_core.ModuleImportedReference,
) -> String {
  "\{export_kind_text(import_.kind)} \{import_.module_path_text}::\{import_.name}"
}

///|
fn export_text(export_ : @buslane_lowering.BuslaneModuleExport) -> String {
  "\{export_kind_text(export_.kind)} \{export_.name}"
}

///|
fn export_kind_text(kind : @buslane_lowering.BuslaneModuleExportKind) -> String {
  match kind {
    Type => "type"
    DataConstructor => "data constructor"
    Effect => "effect"
    Operation => "operation"
    FieldSelector => "field selector"
    Value => "value"
  }
}
