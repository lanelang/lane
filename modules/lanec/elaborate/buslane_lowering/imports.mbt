///|
fn BuslaneLowerer::seed_imported_interfaces(
  self : BuslaneLowerer,
  imported : @module_interface.ModuleImportEnvironments,
) -> Result[Unit, BuslaneLoweringError] {
  Ok(self.seed_imported_interfaces_or_raise(imported)) catch {
    error => Err(error)
  }
}

///|
fn BuslaneLowerer::seed_imported_interfaces_or_raise(
  self : BuslaneLowerer,
  imported : @module_interface.ModuleImportEnvironments,
) -> Unit raise BuslaneLoweringError {
  for interface in imported.direct.modules {
    for type_ in interface.types {
      self.seed_imported_type_header(interface.module_path, type_)
    }
  }
  for interface in imported.direct.modules {
    for effect in interface.effects {
      self.seed_imported_effect_header(interface.module_path, effect)
    }
  }
  for interface in imported.direct.modules {
    self.seed_imported_dependency_headers(interface, imported.available)
  }
  for interface in imported.direct.modules {
    for type_ in interface.types {
      self.seed_imported_type_constructors(interface.module_path, type_)
    }
  }
  for interface in imported.direct.modules {
    for effect in interface.effects {
      self.seed_imported_effect_operations(interface.module_path, effect)
    }
  }
  for interface in imported.direct.modules {
    for value in interface.values {
      self.seed_imported_value(interface.module_path, value)
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_type_header(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit raise BuslaneLoweringError {
  if self.registry.find_type(interface_type_symbol(type_)) is Some(_) {
    return
  }
  match type_ {
    Struct(declaration) => {
      let parameters = declaration.type_parameters.map(parameter => {
        self.define_type_parameter(parameter)
      })
      for type_member in declaration.type_members {
        ignore(self.define_type_parameter(type_member.type_parameter))
      }
      let target = metadata_allocation_or_lowering_defect(() => {
        self.metadata.define_type(declaration.name, parameters)
      })
      ignore(self.registry.register_type(declaration.symbol, target))
      self.imports.push({
        module_path_text,
        name: declaration.name,
        reference: Type(target),
      })
    }
    Enum(declaration) => {
      let parameters = declaration.type_parameters.map(parameter => {
        self.define_type_parameter(parameter)
      })
      for variant in declaration.variants {
        for parameter in variant.type_parameters {
          ignore(self.define_type_parameter(parameter))
        }
      }
      let target = metadata_allocation_or_lowering_defect(() => {
        self.metadata.define_type(declaration.name, parameters)
      })
      ignore(self.registry.register_type(declaration.symbol, target))
      self.imports.push({
        module_path_text,
        name: declaration.name,
        reference: Type(target),
      })
    }
    External(declaration) => {
      let target = metadata_allocation_or_lowering_defect(() => {
        self.metadata.define_type(declaration.name, [], flavor=External)
      })
      ignore(self.registry.register_type(declaration.symbol, target))
      self.imports.push({
        module_path_text,
        name: declaration.name,
        reference: Type(target),
      })
    }
  }
}

///|
fn interface_type_symbol(
  type_ : @module_interface.ModuleInterfaceType,
) -> @symbol.TypeSymbolId {
  match type_ {
    Struct(declaration) => declaration.symbol
    Enum(declaration) => declaration.symbol
    External(declaration) => declaration.symbol
  }
}

///|
fn interface_type_name(type_ : @module_interface.ModuleInterfaceType) -> String {
  match type_ {
    Struct(declaration) => declaration.name
    Enum(declaration) => declaration.name
    External(declaration) => declaration.name
  }
}

///|
/// Seeds every constructor of a directly imported type.
///
/// A direct import can name the type, so building a value of it is reachable
/// and its data constructors become link edges. Types reached only through the
/// interface closure get the narrower
/// `seed_unimported_owner_visible_members` treatment instead.
///
/// Seeding is idempotent: a type reached both ways is defined once.
fn BuslaneLowerer::seed_imported_type_constructors(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit raise BuslaneLoweringError {
  match type_ {
    Struct(declaration) => {
      if self.registry.find_struct_constructor(declaration.symbol) is Some(_) {
        for field in declaration.fields {
          self.seed_imported_field_selector(
            module_path_text, declaration, field,
          )
        }
        return
      }
      let owner = self.type_id(declaration.symbol)
      let hidden_type_parameters = declaration.type_members.map(type_member => {
        self.define_type_parameter(type_member.type_parameter)
      })
      let payload_types = declaration.fields.map(field => {
        self.lower_type(field.type_)
      })
      let data_constructor = metadata_allocation_or_lowering_defect(() => {
        self.metadata.define_data_constructor(
          declaration.name,
          owner,
          hidden_type_parameters,
          payload_types,
        )
      })
      ignore(
        self.registry.register_struct_constructor(
          declaration.symbol,
          data_constructor,
        ),
      )
      self.imports.push({
        module_path_text,
        name: declaration.name,
        reference: DataConstructor(data_constructor),
      })
      for field in declaration.fields {
        self.seed_imported_field_selector(module_path_text, declaration, field)
      }
    }
    Enum(declaration) =>
      self.seed_imported_variant_constructors(module_path_text, declaration)
    External(_) => ()
  }
}

///|
/// Seeds the data constructors of an imported enum.
///
/// Variants are owner-visible members reachable through unqualified patterns,
/// so this runs for enums reached through the interface closure as well as for
/// directly imported ones.
fn BuslaneLowerer::seed_imported_variant_constructors(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @module_interface.ModuleInterfaceEnum,
) -> Unit raise BuslaneLoweringError {
  let owner = self.type_id(declaration.symbol)
  for variant in declaration.variants {
    if self.registry.find_data_constructor(variant.symbol) is Some(_) {
      continue
    }
    let hidden_type_parameters = variant.type_parameters.map(parameter => {
      self.define_type_parameter(parameter)
    })
    let payload_types = variant.payload.map(type_ => self.lower_type(type_))
    let data_constructor = metadata_allocation_or_lowering_defect(() => {
      self.metadata.define_data_constructor(
        variant.name,
        owner,
        hidden_type_parameters,
        payload_types,
      )
    })
    ignore(
      self.registry.register_data_constructor(variant.symbol, data_constructor),
    )
    self.imports.push({
      module_path_text,
      name: variant.name,
      reference: DataConstructor(data_constructor),
    })
  }
}

///|
fn BuslaneLowerer::seed_imported_field_selector(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> Unit raise BuslaneLoweringError {
  if self.registry.find_field_selector(field.symbol) is Some(_) {
    return
  }
  let selector_type = self.imported_selector_type(declaration, field)
  let selector = self.define_fresh_value(field.name, Function, selector_type)
  ignore(self.registry.register_field_selector(field.symbol, selector))
  self.imports.push({
    module_path_text,
    name: field_selector_export_name(declaration.name, field.name),
    reference: FieldSelector(selector),
  })
}

///|
fn BuslaneLowerer::imported_selector_type(
  self : BuslaneLowerer,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> @buslane.Type raise BuslaneLoweringError {
  let type_parameters = declaration.type_parameters.map(parameter => {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    type_parameters.push(self.define_type_parameter(type_member.type_parameter))
  }
  let receiver = buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(parameter => {
      self.lower_type_parameter_argument(parameter)
    }),
  )
  let function = @buslane.Type::Function(
    [receiver],
    self.lower_type(field.type_),
    Empty,
  )
  if type_parameters.is_empty() {
    function
  } else {
    Forall(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::seed_imported_effect_header(
  self : BuslaneLowerer,
  module_path_text : String,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit raise BuslaneLoweringError {
  if self.registry.find_effect(effect.symbol) is Some(_) {
    return
  }
  let parameters = effect.type_parameters.map(parameter => {
    self.define_type_parameter(parameter)
  })
  let flavor = match effect.flavor {
    Algebraic => @buslane.EffectFlavor::Algebraic
    External => External
  }
  let target = metadata_allocation_or_lowering_defect(() => {
    self.metadata.define_effect(effect.name, parameters, flavor~)
  })
  ignore(self.registry.register_effect(effect.symbol, target))
  self.imports.push({
    module_path_text,
    name: effect.name,
    reference: Effect(target),
  })
}

///|
fn BuslaneLowerer::seed_imported_effect_operations(
  self : BuslaneLowerer,
  module_path_text : String,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit raise BuslaneLoweringError {
  let owner = self.effect_id(effect.symbol)
  for operation in effect.operations {
    let target = self.define_operation(
      operation.symbol,
      operation.name,
      owner,
      operation.type_parameters,
      operation.payload,
      operation.result,
    )
    self.imports.push({
      module_path_text,
      name: effect_operation_export_name(effect.name, operation.name),
      reference: Operation(target),
    })
  }
}

///|
fn BuslaneLowerer::seed_imported_value(
  self : BuslaneLowerer,
  module_path_text : String,
  value : @module_interface.ModuleInterfaceValue,
) -> Unit raise BuslaneLoweringError {
  let type_ = self.lower_type(value.type_)
  let kind : @buslane.ValueKind = match value.kind {
    Function => Function
    Let => Value
  }
  let target = self.define_value(value.symbol, value.name, kind, type_)
  self.imports.push({
    module_path_text,
    name: value.name,
    reference: Value(target),
  })
}
