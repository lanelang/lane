///|
/// Stable digest of the source-independent semantics exported by a module
/// interface.
pub(all) struct ModuleInterfaceSemanticFingerprint {
  value : String
} derive(Debug, Eq)

///|
/// Stable digest of interface metadata that affects source presentation.
pub(all) struct ModuleInterfacePresentationFingerprint {
  value : String
} derive(Debug, Eq)

///|
priv struct ModuleInterfaceFingerprints {
  semantic : ModuleInterfaceSemanticFingerprint
  presentation : ModuleInterfacePresentationFingerprint
}

///|
priv struct CanonicalInterfaceEncoding {
  semantic : Bytes
  presentation : Bytes
}

///|
priv struct CanonicalInterfaceEncoder {
  writer : @bytecodec.ByteWriter
  presentation : @bytecodec.ByteWriter
  interface : ModuleInterface
  type_parameters : Array[@symbol.TypeParameterId]
}

///|
priv suberror CanonicalInterfaceEncodingError {
  InvalidCanonicalInterface(String)
}

///|
/// Computes the semantic fingerprint of a compiler-produced module interface.
/// An invalid interface violates an internal compiler invariant and aborts.
pub fn ModuleInterface::semantic_fingerprint(
  self : ModuleInterface,
) -> ModuleInterfaceSemanticFingerprint {
  match self.semantic_fingerprint_result() {
    Ok(fingerprint) => fingerprint
    Err(message) => abort("invalid module interface: " + message)
  }
}

///|
/// Validates and fingerprints an interface from an untrusted source such as an
/// artifact.
pub fn ModuleInterface::semantic_fingerprint_result(
  self : ModuleInterface,
) -> Result[ModuleInterfaceSemanticFingerprint, String] {
  match self.fingerprints_result() {
    Ok(fingerprints) => Ok(fingerprints.semantic)
    Err(message) => Err(message)
  }
}

///|
/// Computes the fingerprint used to reuse source presentation metadata.
pub fn ModuleInterface::presentation_fingerprint(
  self : ModuleInterface,
) -> ModuleInterfacePresentationFingerprint {
  match self.fingerprints_result() {
    Ok(fingerprints) => fingerprints.presentation
    Err(message) => abort("invalid module interface: " + message)
  }
}

///|
fn ModuleInterface::fingerprints_result(
  self : ModuleInterface,
) -> Result[ModuleInterfaceFingerprints, String] {
  match self.canonical_interface_encoding() {
    Ok(encoding) => {
      let semantic : ModuleInterfaceSemanticFingerprint = {
        value: fingerprint_hash(
          "lane-interface-fingerprint-v2",
          encoding.semantic,
        ),
      }
      let presentation_payload = @bytecodec.ByteWriter::new()
      presentation_payload.write_string(semantic.value)
      presentation_payload.write_raw_bytes(encoding.presentation)
      let presentation : ModuleInterfacePresentationFingerprint = {
        value: fingerprint_hash(
          "lane-interface-presentation-fingerprint-v2",
          presentation_payload.to_bytes(),
        ),
      }
      Ok({ semantic, presentation })
    }
    Err(message) => Err(message)
  }
}

///|
fn fingerprint_hash(tag : String, payload : Bytes) -> String {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_string(tag)
  writer.write_raw_bytes(payload)
  "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(writer.to_bytes()))}"
}

///|
fn ModuleInterface::canonical_interface_encoding(
  self : ModuleInterface,
) -> Result[CanonicalInterfaceEncoding, String] {
  try {
    let writer = @bytecodec.ByteWriter::new()
    let presentation = @bytecodec.ByteWriter::new()
    let encoder = CanonicalInterfaceEncoder::{
      writer,
      presentation,
      interface: self,
      type_parameters: [],
    }
    encoder.write_interface()
    Ok({ semantic: writer.to_bytes(), presentation: presentation.to_bytes() })
  } catch {
    InvalidCanonicalInterface(message) => Err(message)
  }
}

///|
fn CanonicalInterfaceEncoder::write_interface(
  self : CanonicalInterfaceEncoder,
) -> Unit raise CanonicalInterfaceEncodingError {
  self.writer.write_string(self.interface.module_path)
  self.write_types(self.interface.types)
  self.write_effects(self.interface.effects)
  self.write_type_aliases(self.interface.type_aliases)
  self.write_values(self.interface.values)
  self.writer.write_u32_le_int(self.interface.optimization_hints.length())
  for hint in self.interface.optimization_hints {
    self.writer.write_string(hint.name)
  }
}

///|
fn CanonicalInterfaceEncoder::write_types(
  self : CanonicalInterfaceEncoder,
  types : Array[ModuleInterfaceType],
) -> Unit raise CanonicalInterfaceEncodingError {
  self.writer.write_u32_le_int(types.length())
  for type_ in types {
    match type_ {
      Struct(declaration) => {
        self.writer.write_u8(0)
        self.writer.write_string(declaration.name)
        self.write_type_parameters(declaration.type_parameters)
        self.writer.write_u32_le_int(declaration.type_members.length())
        for type_member in declaration.type_members {
          self.writer.write_string(type_member.name)
          self.write_kind(type_member.kind)
          self.writer.write_u32_le_int(type_member.index)
        }
        let field_encoder = self
          .with_type_parameters(declaration.type_parameters)
          .with_type_parameters(
            declaration.type_members.map(fn(type_member) {
              type_member.type_parameter
            }),
          )
        self.writer.write_u32_le_int(declaration.fields.length())
        for field in declaration.fields {
          self.writer.write_string(field.name)
          self.writer.write_u32_le_int(field.index)
          field_encoder.write_type(field.type_)
        }
      }
      Enum(declaration) => {
        self.writer.write_u8(1)
        self.writer.write_string(declaration.name)
        self.write_type_parameters(declaration.type_parameters)
        let variant_encoder = self.with_type_parameters(
          declaration.type_parameters,
        )
        self.writer.write_u32_le_int(declaration.variants.length())
        for variant in declaration.variants {
          self.writer.write_string(variant.name)
          self.writer.write_u32_le_int(variant.index)
          self.write_type_parameters(variant.type_parameters)
          let payload_encoder = variant_encoder.with_type_parameters(
            variant.type_parameters,
          )
          self.writer.write_u32_le_int(variant.payload.length())
          for payload in variant.payload {
            payload_encoder.write_type(payload)
          }
        }
      }
      External(declaration) => {
        self.writer.write_u8(2)
        self.writer.write_string(declaration.name)
      }
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_effects(
  self : CanonicalInterfaceEncoder,
  effects : Array[ModuleInterfaceEffect],
) -> Unit raise CanonicalInterfaceEncodingError {
  self.writer.write_u32_le_int(effects.length())
  for effect in effects {
    self.writer.write_string(effect.name)
    self.writer.write_u8(
      match effect.flavor {
        Algebraic => 0
        External => 1
      },
    )
    self.write_type_parameters(effect.type_parameters)
    let effect_encoder = self.with_type_parameters(effect.type_parameters)
    self.writer.write_u32_le_int(effect.operations.length())
    for operation in effect.operations {
      self.writer.write_string(operation.name)
      self.writer.write_u32_le_int(operation.index)
      self.write_type_parameters(operation.type_parameters)
      let operation_encoder = effect_encoder.with_type_parameters(
        operation.type_parameters,
      )
      self.writer.write_u32_le_int(operation.payload.length())
      for payload in operation.payload {
        operation_encoder.write_type(payload)
      }
      operation_encoder.write_type(operation.result)
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_type_aliases(
  self : CanonicalInterfaceEncoder,
  aliases : Array[ModuleInterfaceTypeAlias],
) -> Unit raise CanonicalInterfaceEncodingError {
  self.writer.write_u32_le_int(aliases.length())
  for alias_ in aliases {
    self.writer.write_string(alias_.name)
    self.write_type_parameters(alias_.type_parameters)
    self.write_kind(alias_.kind)
    let alias_encoder = self.with_type_parameters(alias_.type_parameters)
    match alias_.body {
      TypeBody(type_) => {
        self.writer.write_u8(0)
        alias_encoder.write_type(type_)
      }
      EffectBody(effect) => {
        self.writer.write_u8(1)
        alias_encoder.write_effect(effect)
      }
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_values(
  self : CanonicalInterfaceEncoder,
  values : Array[ModuleInterfaceValue],
) -> Unit raise CanonicalInterfaceEncodingError {
  self.writer.write_u32_le_int(values.length())
  for value in values {
    self.writer.write_string(value.name)
    self.writer.write_u8(
      match value.kind {
        Function => 0
        Let => 1
      },
    )
    self.writer.write_bool(value.is_offered)
    self.write_type(value.type_)
    let parameter_encoder = match value.type_ {
      Forall(parameters, _) => self.with_type_parameters(parameters)
      _ => self
    }
    match value.parameters {
      Some(parameters) => {
        self.writer.write_bool(true)
        self.writer.write_u32_le_int(parameters.length())
        for parameter in parameters {
          self.writer.write_string(parameter.name)
          self.writer.write_bool(parameter.is_auto)
          self.writer.write_bool(parameter.is_offered)
          parameter_encoder.write_type(parameter.type_)
        }
      }
      None => self.writer.write_bool(false)
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_type_parameters(
  self : CanonicalInterfaceEncoder,
  parameters : Array[@types.TypeParameter],
) -> Unit {
  self.writer.write_u32_le_int(parameters.length())
  self.presentation.write_u32_le_int(parameters.length())
  for parameter in parameters {
    self.write_kind(parameter.kind)
    self.presentation.write_string(parameter.name)
  }
}

///|
fn CanonicalInterfaceEncoder::write_kind(
  self : CanonicalInterfaceEncoder,
  kind : @types.Kind,
) -> Unit {
  match kind {
    Type => self.writer.write_u8(0)
    Effect => self.writer.write_u8(1)
    Function(parameters, result) => {
      self.writer.write_u8(2)
      self.writer.write_u32_le_int(parameters.length())
      for parameter in parameters {
        self.write_kind(parameter)
      }
      self.write_kind(result)
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_type(
  self : CanonicalInterfaceEncoder,
  type_ : @types.Type,
) -> Unit raise CanonicalInterfaceEncodingError {
  match type_ {
    Error => self.writer.write_u8(0)
    Primitive(primitive) => {
      self.writer.write_u8(1)
      self.writer.write_u8(
        match primitive {
          Int => 0
          Double => 1
          Bool => 2
          String => 3
          Unit => 4
        },
      )
    }
    Constructor(symbol) => {
      self.writer.write_u8(2)
      let (module_path, name) = self.type_reference(symbol)
      self.writer.write_string(module_path)
      self.writer.write_string(name)
    }
    Apply(callee, arguments) => {
      self.writer.write_u8(3)
      self.write_type(callee)
      self.writer.write_u32_le_int(arguments.length())
      for argument in arguments {
        self.write_generic_argument(argument)
      }
    }
    TypeLambda(parameters, body) => {
      self.writer.write_u8(4)
      self.write_type_parameters(parameters)
      self.with_type_parameters(parameters).write_type(body)
    }
    Parameter(symbol) => {
      self.writer.write_u8(5)
      self.writer.write_u32_le_int(self.type_parameter_index(symbol))
    }
    Function(parameters, result, effect) => {
      self.writer.write_u8(6)
      self.writer.write_u32_le_int(parameters.length())
      for parameter in parameters {
        self.write_type(parameter)
      }
      self.write_type(result)
      self.write_effect(effect)
    }
    Forall(parameters, body) => {
      self.writer.write_u8(7)
      self.write_type_parameters(parameters)
      self.with_type_parameters(parameters).write_type(body)
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_effect(
  self : CanonicalInterfaceEncoder,
  effect : @types.Effect,
) -> Unit raise CanonicalInterfaceEncodingError {
  match effect {
    Empty => self.writer.write_u8(0)
    Io => self.writer.write_u8(1)
    Singleton(symbol, arguments) => {
      self.writer.write_u8(2)
      let (module_path, name) = self.effect_reference(symbol)
      self.writer.write_string(module_path)
      self.writer.write_string(name)
      self.writer.write_u32_le_int(arguments.length())
      for argument in arguments {
        self.write_generic_argument(argument)
      }
    }
    Parameter(symbol) => {
      self.writer.write_u8(3)
      self.writer.write_u32_le_int(self.type_parameter_index(symbol))
    }
    Union(effects) => {
      self.writer.write_u8(4)
      self.writer.write_u32_le_int(effects.length())
      for item in effects {
        self.write_effect(item)
      }
    }
  }
}

///|
fn CanonicalInterfaceEncoder::write_generic_argument(
  self : CanonicalInterfaceEncoder,
  argument : @types.GenericArgument,
) -> Unit raise CanonicalInterfaceEncodingError {
  match argument {
    TypeArgument(type_) => {
      self.writer.write_u8(0)
      self.write_type(type_)
    }
    EffectArgument(effect) => {
      self.writer.write_u8(1)
      self.write_effect(effect)
    }
  }
}

///|
fn CanonicalInterfaceEncoder::with_type_parameters(
  self : CanonicalInterfaceEncoder,
  parameters : Array[@types.TypeParameter],
) -> CanonicalInterfaceEncoder {
  let type_parameters = self.type_parameters.copy()
  for parameter in parameters {
    type_parameters.push(parameter.id)
  }
  { ..self, type_parameters, }
}

///|
fn CanonicalInterfaceEncoder::type_parameter_index(
  self : CanonicalInterfaceEncoder,
  symbol : @symbol.TypeParameterId,
) -> Int raise CanonicalInterfaceEncodingError {
  for offset in 0..<self.type_parameters.length() {
    let index = self.type_parameters.length() - offset - 1
    if self.type_parameters[index] == symbol {
      return offset
    }
  }
  raise InvalidCanonicalInterface("unbound interface type parameter")
}

///|
fn CanonicalInterfaceEncoder::type_reference(
  self : CanonicalInterfaceEncoder,
  symbol : @symbol.TypeSymbolId,
) -> (String, String) raise CanonicalInterfaceEncodingError {
  let mut found : (String, String)? = None
  for reference in self.interface.type_references {
    if reference.symbol == symbol {
      let current = (reference.module_path, reference.name)
      match found {
        Some(previous) if previous != current =>
          raise InvalidCanonicalInterface("ambiguous interface type reference")
        _ => found = Some(current)
      }
    }
  }
  match found {
    Some(reference) => reference
    None =>
      raise InvalidCanonicalInterface("unresolved interface type reference")
  }
}

///|
fn CanonicalInterfaceEncoder::effect_reference(
  self : CanonicalInterfaceEncoder,
  symbol : @symbol.EffectSymbolId,
) -> (String, String) raise CanonicalInterfaceEncodingError {
  let mut found : (String, String)? = None
  for reference in self.interface.effect_references {
    if reference.symbol == symbol {
      let current = (reference.module_path, reference.name)
      match found {
        Some(previous) if previous != current =>
          raise InvalidCanonicalInterface(
            "ambiguous interface effect reference",
          )
        _ => found = Some(current)
      }
    }
  }
  match found {
    Some(reference) => reference
    None =>
      raise InvalidCanonicalInterface("unresolved interface effect reference")
  }
}
