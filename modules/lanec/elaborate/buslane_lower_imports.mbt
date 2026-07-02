///|
fn BuslaneLowerer::seed_imported_interfaces(
  self : BuslaneLowerer,
  imported : @module_interface.ImportedEnvironment,
) -> Unit {
  for interface in imported.modules {
    for type_ in interface.types {
      self.seed_imported_type_header(interface.module_path, type_)
    }
  }
  for interface in imported.modules {
    for type_ in interface.types {
      self.seed_imported_type_constructors(interface.module_path, type_)
    }
  }
  for interface in imported.modules {
    for effect in interface.effects {
      self.seed_imported_effect_header(interface.module_path, effect)
    }
  }
  for interface in imported.modules {
    for effect in interface.effects {
      self.seed_imported_effect_operations(interface.module_path, effect)
    }
  }
  for interface in imported.modules {
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
) -> Unit {
  match type_ {
    Struct(declaration) => {
      let parameters = declaration.type_parameters.map(fn(parameter) {
        self.define_type_parameter(parameter)
      })
      for type_member in declaration.type_members {
        ignore(self.define_type_parameter(type_member.type_parameter))
      }
      let target = self.metadata.define_type(declaration.name, parameters)
      ignore(self.registry.register_type(declaration.symbol, target))
      self.imports.push({
        module_path_text,
        kind: Type,
        name: declaration.name,
        type_id: Some(target),
        data_constructor: None,
        effect_id: None,
        operation: None,
        value: None,
      })
    }
    Enum(declaration) => {
      let parameters = declaration.type_parameters.map(fn(parameter) {
        self.define_type_parameter(parameter)
      })
      for variant in declaration.variants {
        for parameter in variant.type_parameters {
          ignore(self.define_type_parameter(parameter))
        }
      }
      let target = self.metadata.define_type(declaration.name, parameters)
      ignore(self.registry.register_type(declaration.symbol, target))
      self.imports.push({
        module_path_text,
        kind: Type,
        name: declaration.name,
        type_id: Some(target),
        data_constructor: None,
        effect_id: None,
        operation: None,
        value: None,
      })
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_type_constructors(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit {
  match type_ {
    Struct(declaration) => {
      let owner = self.type_id(declaration.symbol)
      let hidden_type_parameters = declaration.type_members.map(fn(
        type_member,
      ) {
        self.define_type_parameter(type_member.type_parameter)
      })
      let payload_types = declaration.fields.map(fn(field) {
        self.lower_type(field.type_)
      })
      let data_constructor = self.metadata.define_data_constructor(
        declaration.name,
        owner,
        hidden_type_parameters,
        payload_types,
      )
      ignore(
        self.registry.register_struct_constructor(
          declaration.symbol,
          data_constructor,
        ),
      )
      self.imports.push({
        module_path_text,
        kind: DataConstructor,
        name: declaration.name,
        type_id: None,
        data_constructor: Some(data_constructor),
        effect_id: None,
        operation: None,
        value: None,
      })
      for field in declaration.fields {
        self.seed_imported_field_selector(module_path_text, declaration, field)
      }
    }
    Enum(declaration) => {
      let owner = self.type_id(declaration.symbol)
      for variant in declaration.variants {
        let hidden_type_parameters = variant.type_parameters.map(fn(parameter) {
          self.define_type_parameter(parameter)
        })
        let payload_types = variant.payload.map(fn(type_) {
          self.lower_type(type_)
        })
        let data_constructor = self.metadata.define_data_constructor(
          variant.name,
          owner,
          hidden_type_parameters,
          payload_types,
        )
        ignore(
          self.registry.register_data_constructor(
            variant.symbol,
            data_constructor,
          ),
        )
        self.imports.push({
          module_path_text,
          kind: DataConstructor,
          name: variant.name,
          type_id: None,
          data_constructor: Some(data_constructor),
          effect_id: None,
          operation: None,
          value: None,
        })
      }
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_field_selector(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> Unit {
  let selector_type = self.imported_selector_type(declaration, field)
  let selector = self.metadata.define_value(field.name, Function, selector_type)
  ignore(self.registry.register_field_selector(field.symbol, selector))
  self.imports.push({
    module_path_text,
    kind: FieldSelector,
    name: field_selector_export_name(declaration.name, field.name),
    type_id: None,
    data_constructor: None,
    effect_id: None,
    operation: None,
    value: Some(selector),
  })
}

///|
fn BuslaneLowerer::imported_selector_type(
  self : BuslaneLowerer,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> @buslane.Type {
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    type_parameters.push(self.define_type_parameter(type_member.type_parameter))
  }
  let receiver = buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(fn(parameter) {
      Parameter(self.type_parameter_id(parameter.id))
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
) -> Unit {
  let parameters = effect.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  let target = self.metadata.define_effect(effect.name, parameters)
  ignore(self.registry.register_effect(effect.symbol, target))
  self.imports.push({
    module_path_text,
    kind: Effect,
    name: effect.name,
    type_id: None,
    data_constructor: None,
    effect_id: Some(target),
    operation: None,
    value: None,
  })
}

///|
fn BuslaneLowerer::seed_imported_effect_operations(
  self : BuslaneLowerer,
  module_path_text : String,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit {
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
      kind: Operation,
      name: effect_operation_export_name(effect.name, operation.name),
      type_id: None,
      data_constructor: None,
      effect_id: None,
      operation: Some(target),
      value: None,
    })
  }
}

///|
fn BuslaneLowerer::seed_imported_value(
  self : BuslaneLowerer,
  module_path_text : String,
  value : @module_interface.ModuleInterfaceValue,
) -> Unit {
  let type_ = self.lower_type(value.type_)
  let kind : @buslane.ValueKind = match value.kind {
    Function => Function
    Let | Offer => Value
  }
  let target = self.define_value(value.symbol, value.name, kind, type_)
  self.imports.push({
    module_path_text,
    kind: Value,
    name: value.name,
    type_id: None,
    data_constructor: None,
    effect_id: None,
    operation: None,
    value: Some(target),
  })
}
