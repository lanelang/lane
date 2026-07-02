///|
fn BuslaneLowerer::collect_type_headers(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_header(declaration)
      Enum(declaration) => self.collect_enum_header(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::add_entry(
  self : BuslaneLowerer,
  name : String,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit {
  self.entries.push({ name, value, type_ })
}

///|
fn BuslaneLowerer::collect_struct_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    ignore(self.define_type_parameter(type_member.type_parameter))
  }
  let target = self.metadata.define_type(parameters)
  ignore(self.registry.register_type(declaration.symbol, target))
}

///|
fn BuslaneLowerer::collect_enum_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for variant in declaration.variants {
    for parameter in variant.type_parameters {
      ignore(self.define_type_parameter(parameter))
    }
  }
  let target = self.metadata.define_type(parameters)
  ignore(self.registry.register_type(declaration.symbol, target))
}

///|
fn BuslaneLowerer::collect_effect_headers(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    if declaration is Effect(declaration) {
      self.collect_effect_header(declaration)
    }
  }
}

///|
fn BuslaneLowerer::collect_effect_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEffectDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  let target = self.metadata.define_effect(parameters)
  ignore(self.registry.register_effect(declaration.symbol, target))
}

///|
fn BuslaneLowerer::collect_data_constructors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_constructor(declaration)
      Enum(declaration) => self.collect_enum_constructors(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::collect_struct_constructor(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  let hidden_type_parameters = declaration.type_members.map(fn(type_member) {
    self.define_type_parameter(type_member.type_parameter)
  })
  let payload_types = declaration.fields.map(fn(field) {
    self.lower_type(field.type_)
  })
  let target = self.metadata.define_data_constructor(
    owner, hidden_type_parameters, payload_types,
  )
  ignore(self.registry.register_struct_constructor(declaration.symbol, target))
}

///|
fn BuslaneLowerer::collect_enum_constructors(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  for variant in declaration.variants {
    let hidden_type_parameters = variant.type_parameters.map(fn(parameter) {
      self.define_type_parameter(parameter)
    })
    let payload_types = variant.payload.map(fn(type_) { self.lower_type(type_) })
    let target = self.metadata.define_data_constructor(
      owner, hidden_type_parameters, payload_types,
    )
    ignore(self.registry.register_data_constructor(variant.symbol, target))
  }
}

///|
fn BuslaneLowerer::collect_effect_operations(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    if declaration is Effect(declaration) {
      self.collect_effect_operation_declarations(declaration)
    }
  }
}

///|
fn BuslaneLowerer::collect_effect_operation_declarations(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEffectDeclaration,
) -> Unit {
  let owner = self.effect_id(declaration.symbol)
  for operation in declaration.operations {
    ignore(
      self.define_operation(
        operation.symbol,
        owner,
        operation.type_parameters,
        operation.payload,
        operation.result,
      ),
    )
  }
}

///|
fn BuslaneLowerer::collect_field_selectors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  let module_path_text = checked_module_path_text(source)
  for declaration in source.declarations {
    if declaration is Struct(declaration) {
      for index in 0..<declaration.fields.length() {
        self.collect_field_selector(module_path_text, declaration, index)
      }
    }
  }
}

///|
fn BuslaneLowerer::collect_field_selector(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
) -> Unit {
  let field = declaration.fields[field_index]
  let type_parameters = self.selector_type_parameters(declaration)
  let selector_type = self.selector_type(declaration, field)
  let selector = self.metadata.define_value(Function, selector_type)
  ignore(self.registry.register_field_selector(field.symbol, selector))
  self.selector_terms.push({
    module_path_text,
    term: Let(
      selector,
      self.selector_body(declaration, field_index, type_parameters),
    ),
  })
}

///|
fn BuslaneLowerer::selector_type_parameters(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Array[@buslane.TypeParameterId] {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    parameters.push(self.define_type_parameter(type_member.type_parameter))
  }
  parameters
}

///|
fn BuslaneLowerer::selector_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field : @checked.CheckedFieldDeclaration,
) -> @buslane.Type {
  let function = @buslane.Type::Function(
    [self.selector_receiver_type(declaration)],
    self.lower_type(field.type_),
    Empty,
  )
  let type_parameters = self.selector_type_parameters(declaration)
  if type_parameters.is_empty() {
    function
  } else {
    Forall(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::selector_receiver_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> @buslane.Type {
  buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(fn(parameter) {
      Parameter(self.type_parameter_id(parameter.id))
    }),
  )
}

///|
fn BuslaneLowerer::selector_body(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
  type_parameters : Array[@buslane.TypeParameterId],
) -> @buslane.Expr {
  let receiver_type = self.selector_receiver_type(declaration)
  let receiver = self.metadata.define_value(Parameter, receiver_type)
  let result_type = self.lower_type(declaration.fields[field_index].type_)
  let match_binder = self.metadata.define_value(MatchBinder, receiver_type)
  let value_binders = declaration.fields.map(fn(field) {
    self.metadata.define_value(MatchBinder, self.lower_type(field.type_))
  })
  let function = @buslane.Expr::Function({
    parameters: [receiver],
    result_type,
    body: Match({
      scrutinee: Ref(receiver),
      binder: match_binder,
      result_type,
      alternatives: [
        {
          alt_constructor: DataCon(
            self.struct_constructor_id(declaration.symbol),
          ),
          type_binders: declaration.type_members.map(fn(type_member) {
            self.type_parameter_id(type_member.type_parameter.id)
          }),
          value_binders,
          body: Ref(value_binders[field_index]),
        },
      ],
    }),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::collect_top_values(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
  include_entries~ : Bool,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Function(declaration) => {
        for parameter in declaration.type_parameters {
          ignore(self.define_type_parameter(parameter))
        }
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Function, type_)
        if include_entries && declaration.is_public {
          self.add_entry(declaration.name, value, type_)
        }
      }
      Let(declaration) => {
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Value, type_)
        if include_entries && declaration.is_public {
          if declaration.name is Some(name) {
            self.add_entry(name, value, type_)
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::lower_top_terms(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Array[@buslane.TopTerm] {
  let terms : Array[@buslane.TopTerm] = []
  for selector in self.selector_terms {
    if selector.module_path_text == checked_module_path_text(source) {
      terms.push(selector.term)
    }
  }
  let recursive_functions : Array[@buslane.RecursiveBinding] = []
  for declaration in source.declarations {
    if declaration is Function(function) {
      recursive_functions.push(self.lower_recursive_function(function))
    }
  }
  if !recursive_functions.is_empty() {
    terms.push(LetRec(recursive_functions))
  }
  for declaration in source.declarations {
    if declaration is Let(declaration) {
      terms.push(
        Let(
          self.value_id(declaration.symbol),
          self.lower_expr(declaration.initializer),
        ),
      )
    }
  }
  terms
}

///|
fn BuslaneLowerer::lower_recursive_function(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.RecursiveBinding {
  {
    id: self.value_id(declaration.symbol),
    rhs: self.lower_function_declaration(declaration),
  }
}

///|
fn BuslaneLowerer::lower_function_declaration(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.Expr {
  for parameter in declaration.type_parameters {
    ignore(self.define_type_parameter(parameter))
  }
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: declaration.parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        Parameter,
        self.lower_type(parameter.type_),
      )
    }),
    result_type: self.lower_type(declaration.return_type),
    body: self.lower_expr(declaration.body),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}
