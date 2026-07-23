///|
fn @bytecodec.ByteWriter::write_module_interface(
  self : @bytecodec.ByteWriter,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  self.write_string(interface.module_path)
  self.write_module_interface_type_references(interface.type_references)
  self.write_module_interface_effect_references(interface.effect_references)
  self.write_module_interface_types(interface.types)
  self.write_module_interface_effects(interface.effects)
  self.write_module_interface_type_aliases(interface.type_aliases)
  self.write_module_interface_values(interface.values)
  self.write_optimization_hints(interface.optimization_hints)
}

///|
fn @bytecodec.ByteReader::read_module_interface(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterface raise {
  {
    module_path: self.read_string(),
    source_id: None,
    type_references: self.read_module_interface_type_references(),
    effect_references: self.read_module_interface_effect_references(),
    types: self.read_module_interface_types(),
    effects: self.read_module_interface_effects(),
    type_aliases: self.read_module_interface_type_aliases(),
    values: self.read_module_interface_values(),
    optimization_hints: self.read_optimization_hints(),
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_type_references(
  self : @bytecodec.ByteWriter,
  references : Array[@module_interface.ModuleInterfaceTypeReference],
) -> Unit {
  self.write_u32_le_int(references.length())
  for reference in references {
    self.write_type_symbol_id(reference.symbol)
    self.write_string(reference.module_path)
    self.write_string(reference.name)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_type_references(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceTypeReference] raise {
  let references : Array[@module_interface.ModuleInterfaceTypeReference] = []
  for _ in 0..<self.read_u32_le_int() {
    references.push({
      symbol: self.read_type_symbol_id(),
      module_path: self.read_string(),
      name: self.read_string(),
    })
  }
  references
}

///|
fn @bytecodec.ByteWriter::write_module_interface_effect_references(
  self : @bytecodec.ByteWriter,
  references : Array[@module_interface.ModuleInterfaceEffectReference],
) -> Unit {
  self.write_u32_le_int(references.length())
  for reference in references {
    self.write_effect_symbol_id(reference.symbol)
    self.write_string(reference.module_path)
    self.write_string(reference.name)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_effect_references(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceEffectReference] raise {
  let references : Array[@module_interface.ModuleInterfaceEffectReference] = []
  for _ in 0..<self.read_u32_le_int() {
    references.push({
      symbol: self.read_effect_symbol_id(),
      module_path: self.read_string(),
      name: self.read_string(),
    })
  }
  references
}

///|
fn @bytecodec.ByteWriter::write_module_interface_types(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceType],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_module_interface_type(item)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_types(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceType] raise {
  let items : Array[@module_interface.ModuleInterfaceType] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push(self.read_module_interface_type())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_type(
  self : @bytecodec.ByteWriter,
  item : @module_interface.ModuleInterfaceType,
) -> Unit {
  match item {
    Struct(declaration) => {
      self.write_u8(0)
      self.write_type_symbol_id(declaration.symbol)
      self.write_string(declaration.name)
      self.write_type_parameters(declaration.type_parameters)
      self.write_type_members(declaration.type_members)
      self.write_fields(declaration.fields)
      self.write_source_span(declaration.loc)
    }
    Enum(declaration) => {
      self.write_u8(1)
      self.write_type_symbol_id(declaration.symbol)
      self.write_string(declaration.name)
      self.write_type_parameters(declaration.type_parameters)
      self.write_variants(declaration.variants)
      self.write_source_span(declaration.loc)
    }
    External(declaration) => {
      self.write_u8(2)
      self.write_type_symbol_id(declaration.symbol)
      self.write_string(declaration.name)
      self.write_source_span(declaration.loc)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_type(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceType raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Struct({
        symbol: self.read_type_symbol_id(),
        name: self.read_string(),
        type_parameters: self.read_type_parameters(),
        type_members: self.read_type_members(),
        fields: self.read_fields(),
        loc: self.read_source_span(),
      })
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Enum({
        symbol: self.read_type_symbol_id(),
        name: self.read_string(),
        type_parameters: self.read_type_parameters(),
        variants: self.read_variants(),
        loc: self.read_source_span(),
      })
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      External({
        symbol: self.read_type_symbol_id(),
        name: self.read_string(),
        loc: self.read_source_span(),
      })
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="ModuleInterfaceType",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_type_members(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceTypeMember],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_type_member_symbol_id(item.symbol)
    self.write_type_parameter(item.type_parameter)
    self.write_string(item.name)
    self.write_lane_kind(item.kind)
    self.write_u32_le_int(item.index)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_type_members(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceTypeMember] raise {
  let items : Array[@module_interface.ModuleInterfaceTypeMember] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_type_member_symbol_id(),
      type_parameter: self.read_type_parameter(),
      name: self.read_string(),
      kind: self.read_lane_kind(),
      index: self.read_u32_le_int(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_fields(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceField],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_field_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_u32_le_int(item.index)
    self.write_lane_type(item.type_)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_fields(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceField] raise {
  let items : Array[@module_interface.ModuleInterfaceField] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_field_symbol_id(),
      name: self.read_string(),
      index: self.read_u32_le_int(),
      type_: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_variants(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceVariant],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_variant_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_u32_le_int(item.index)
    self.write_type_parameters(item.type_parameters)
    self.write_lane_types(item.payload)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_variants(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceVariant] raise {
  let items : Array[@module_interface.ModuleInterfaceVariant] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_variant_symbol_id(),
      name: self.read_string(),
      index: self.read_u32_le_int(),
      type_parameters: self.read_type_parameters(),
      payload: self.read_lane_types(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_effects(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceEffect],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_effect_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_interface_effect_flavor(item.flavor)
    self.write_type_parameters(item.type_parameters)
    self.write_module_interface_operations(item.operations)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_effects(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceEffect] raise {
  let items : Array[@module_interface.ModuleInterfaceEffect] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_effect_symbol_id(),
      name: self.read_string(),
      flavor: self.read_interface_effect_flavor(),
      type_parameters: self.read_type_parameters(),
      operations: self.read_module_interface_operations(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_interface_effect_flavor(
  self : @bytecodec.ByteWriter,
  flavor : @symbol.EffectFlavor,
) -> Unit {
  self.write_u8(
    match flavor {
      Algebraic => 0
      External => 1
    },
  )
}

///|
fn @bytecodec.ByteReader::read_interface_effect_flavor(
  self : @bytecodec.ByteReader,
) -> @symbol.EffectFlavor raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Algebraic
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      External
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="EffectFlavor",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_operations(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceOperation],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_operation_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_u32_le_int(item.index)
    self.write_type_parameters(item.type_parameters)
    self.write_lane_types(item.payload)
    self.write_lane_type(item.result)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_operations(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceOperation] raise {
  let items : Array[@module_interface.ModuleInterfaceOperation] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_operation_symbol_id(),
      name: self.read_string(),
      index: self.read_u32_le_int(),
      type_parameters: self.read_type_parameters(),
      payload: self.read_lane_types(),
      result: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_type_aliases(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceTypeAlias],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_string(item.name)
    self.write_type_parameters(item.type_parameters)
    self.write_type_alias_body(item.body)
    self.write_lane_kind(item.kind)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_type_aliases(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceTypeAlias] raise {
  let items : Array[@module_interface.ModuleInterfaceTypeAlias] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      name: self.read_string(),
      type_parameters: self.read_type_parameters(),
      body: self.read_type_alias_body(),
      kind: self.read_lane_kind(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_type_alias_body(
  self : @bytecodec.ByteWriter,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> Unit {
  match body {
    TypeBody(type_) => {
      self.write_u8(0)
      self.write_lane_type(type_)
    }
    EffectBody(effect) => {
      self.write_u8(1)
      self.write_lane_effect(effect)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_type_alias_body(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceTypeAliasBody raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      TypeBody(self.read_lane_type())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      EffectBody(self.read_lane_effect())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="ModuleInterfaceTypeAliasBody",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_values(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceValue],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_value_symbol_id(item.symbol)
    self.write_module_interface_value_kind(item.kind)
    self.write_bool(item.is_offered)
    self.write_string(item.name)
    self.write_lane_type(item.type_)
    self.write_tuple_presentations(item.tuple_presentations)
    self.write_optional_value_parameters(item.parameters)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_values(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValue] raise {
  let items : Array[@module_interface.ModuleInterfaceValue] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_value_symbol_id(),
      kind: self.read_module_interface_value_kind(),
      is_offered: self.read_bool(),
      name: self.read_string(),
      type_: self.read_lane_type(),
      tuple_presentations: self.read_tuple_presentations(),
      parameters: self.read_optional_value_parameters(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_tuple_presentations(
  self : @bytecodec.ByteWriter,
  presentations : Array[@types.TuplePresentation],
) -> Unit {
  self.write_u32_le_int(presentations.length())
  for presentation in presentations {
    self.write_u32_le_int(presentation.path.length())
    for step in presentation.path {
      self.write_tuple_presentation_path_step(step)
    }
    self.write_u32_le_int(presentation.item_count)
  }
}

///|
fn @bytecodec.ByteReader::read_tuple_presentations(
  self : @bytecodec.ByteReader,
) -> Array[@types.TuplePresentation] raise {
  let presentations : Array[@types.TuplePresentation] = []
  for _ in 0..<self.read_u32_le_int() {
    let path = []
    for _ in 0..<self.read_u32_le_int() {
      path.push(self.read_tuple_presentation_path_step())
    }
    presentations.push({ path, item_count: self.read_u32_le_int() })
  }
  presentations
}

///|
fn @bytecodec.ByteWriter::write_tuple_presentation_path_step(
  self : @bytecodec.ByteWriter,
  step : @types.TuplePresentationPathStep,
) -> Unit {
  match step {
    TypeApplicationCallee => self.write_u8(0)
    TypeApplicationArgument(index) => {
      self.write_u8(1)
      self.write_u32_le_int(index)
    }
    TypeLambdaBody => self.write_u8(2)
    FunctionParameter(index) => {
      self.write_u8(3)
      self.write_u32_le_int(index)
    }
    FunctionResult => self.write_u8(4)
    FunctionEffect => self.write_u8(5)
    EffectTerm => self.write_u8(6)
    EffectUnionItem(index) => {
      self.write_u8(7)
      self.write_u32_le_int(index)
    }
    TupleItem(index) => {
      self.write_u8(8)
      self.write_u32_le_int(index)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_tuple_presentation_path_step(
  self : @bytecodec.ByteReader,
) -> @types.TuplePresentationPathStep raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      TypeApplicationCallee
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      TypeApplicationArgument(self.read_u32_le_int())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      TypeLambdaBody
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      FunctionParameter(self.read_u32_le_int())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      FunctionResult
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      FunctionEffect
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      EffectTerm
    }
    [u8be(7), .. rest] => {
      self.update_view(rest)
      EffectUnionItem(self.read_u32_le_int())
    }
    [u8be(8), .. rest] => {
      self.update_view(rest)
      TupleItem(self.read_u32_le_int())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="TuplePresentationPathStep",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_value_kind(
  self : @bytecodec.ByteWriter,
  kind : @module_interface.ModuleInterfaceValueKind,
) -> Unit {
  self.write_u8(
    match kind {
      Function => 0
      Let => 1
    },
  )
}

///|
fn @bytecodec.ByteReader::read_module_interface_value_kind(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceValueKind raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Function
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Let
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="ModuleInterfaceValueKind",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_optional_value_parameters(
  self : @bytecodec.ByteWriter,
  parameters : Array[@module_interface.ModuleInterfaceValueParameter]?,
) -> Unit {
  match parameters {
    None => self.write_bool(false)
    Some(parameters) => {
      self.write_bool(true)
      self.write_value_parameters(parameters)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_optional_value_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValueParameter]? raise {
  if self.read_bool() {
    Some(self.read_value_parameters())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteWriter::write_value_parameters(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceValueParameter],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_value_symbol_id(item.symbol)
    self.write_bool(item.is_auto)
    self.write_bool(item.is_offered)
    self.write_string(item.name)
    self.write_lane_type(item.type_)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_value_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValueParameter] raise {
  let items : Array[@module_interface.ModuleInterfaceValueParameter] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({
      symbol: self.read_value_symbol_id(),
      is_auto: self.read_bool(),
      is_offered: self.read_bool(),
      name: self.read_string(),
      type_: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_optimization_hints(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.OptimizationHint],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_string(item.name)
  }
}

///|
fn @bytecodec.ByteReader::read_optimization_hints(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.OptimizationHint] raise {
  let items : Array[@module_interface.OptimizationHint] = []
  for _ in 0..<self.read_u32_le_int() {
    items.push({ name: self.read_string() })
  }
  items
}
