///|
fn BuslaneLinker::remap_module_object(
  self : BuslaneLinker,
  object : LinkModuleObject,
) -> RemappedModuleObject {
  {
    module_path_text: object.module_path_text,
    terms: object.terms.map(fn(term) { self.remap_top_term(object, term) }),
    externals: {
      builtins: object.externals.builtins.map(fn(builtin) {
        {
          value: self.remap_value_id(object, builtin.value),
          name: builtin.name,
          type_: self.remap_type(object, builtin.type_),
        }
      }),
      runtime_imports: object.externals.runtime_imports.map(fn(import_) {
        {
          value: self.remap_value_id(object, import_.value),
          symbol: import_.symbol,
          type_: self.remap_type(object, import_.type_),
        }
      }),
    },
    entries: object.entries.map(fn(entry) {
      {
        module_path_text: entry.module_path_text,
        name: entry.name,
        value: self.remap_value_id(object, entry.value),
        type_: self.remap_type(object, entry.type_),
      }
    }),
    exports: object.exports.map(fn(item) {
      {
        kind: item.kind,
        name: item.name,
        type_id: item.type_id.map(fn(id) { self.remap_type_id(object, id) }),
        data_constructor: item.data_constructor.map(fn(id) {
          self.remap_data_constructor_id(object, id)
        }),
        effect_id: item.effect_id.map(fn(id) {
          self.remap_effect_id(object, id)
        }),
        operation: item.operation.map(fn(id) {
          self.remap_operation_id(object, id)
        }),
        value: item.value.map(fn(id) { self.remap_value_id(object, id) }),
      }
    }),
    fingerprint: object.fingerprint,
  }
}

///|
fn BuslaneLinker::remap_top_term(
  self : BuslaneLinker,
  object : LinkModuleObject,
  term : @buslane.TopTerm,
) -> @buslane.TopTerm {
  match term {
    Let(id, expr) =>
      Let(self.remap_value_id(object, id), self.remap_expr(object, expr))
    LetRec(bindings) =>
      LetRec(
        bindings.map(fn(binding) {
          {
            id: self.remap_value_id(object, binding.id),
            rhs: self.remap_expr(object, binding.rhs),
          }
        }),
      )
    External(id) => External(self.remap_value_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_expr(
  self : BuslaneLinker,
  object : LinkModuleObject,
  expr : @buslane.Expr,
) -> @buslane.Expr {
  match expr {
    Ref(id) => Ref(self.remap_value_id(object, id))
    Literal(literal) => Literal(literal)
    Function(function) =>
      Function({
        parameters: function.parameters.map(fn(id) {
          self.remap_value_id(object, id)
        }),
        result_type: self.remap_type(object, function.result_type),
        body: self.remap_expr(object, function.body),
      })
    Call(callee, arguments) =>
      Call(
        self.remap_expr(object, callee),
        arguments.map(fn(argument) { self.remap_expr(object, argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_expr(object, body),
      )
    TypeApply(callee, arguments) =>
      TypeApply(
        self.remap_expr(object, callee),
        arguments.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
      )
    Construct(construct) =>
      Construct({
        data_constructor: self.remap_data_constructor_id(
          object,
          construct.data_constructor,
        ),
        type_arguments: construct.type_arguments.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
        hidden_witnesses: construct.hidden_witnesses.map(fn(witness) {
          self.remap_generic_argument(object, witness)
        }),
        payloads: construct.payloads.map(fn(payload) {
          self.remap_expr(object, payload)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        self.remap_value_id(object, id),
        self.remap_expr(object, initializer),
        self.remap_expr(object, body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(fn(binding) {
          {
            id: self.remap_value_id(object, binding.id),
            rhs: self.remap_expr(object, binding.rhs),
          }
        }),
        self.remap_expr(object, body),
      )
    Match(match_) =>
      Match({
        scrutinee: self.remap_expr(object, match_.scrutinee),
        binder: self.remap_value_id(object, match_.binder),
        result_type: self.remap_type(object, match_.result_type),
        alternatives: match_.alternatives.map(fn(alternative) {
          {
            alt_constructor: self.remap_alt_constructor(
              object,
              alternative.alt_constructor,
            ),
            type_binders: alternative.type_binders.map(fn(id) {
              self.remap_type_parameter_id(object, id)
            }),
            value_binders: alternative.value_binders.map(fn(id) {
              self.remap_value_id(object, id)
            }),
            body: self.remap_expr(object, alternative.body),
          }
        }),
      })
    Perform(perform) =>
      Perform({
        operation: self.remap_operation_id(object, perform.operation),
        effect_arguments: perform.effect_arguments.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
        hidden_witnesses: perform.hidden_witnesses.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
        payloads: perform.payloads.map(fn(payload) {
          self.remap_expr(object, payload)
        }),
      })
    Handle(handle) =>
      Handle({
        body: self.remap_expr(object, handle.body),
        result_binder: self.remap_value_id(object, handle.result_binder),
        result_type: self.remap_type(object, handle.result_type),
        final_body: self.remap_expr(object, handle.final_body),
        handlers: handle.handlers.map(fn(table) {
          self.remap_handler_table(object, table)
        }),
      })
    Resume(id) => Resume(self.remap_value_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_handler_table(
  self : BuslaneLinker,
  object : LinkModuleObject,
  table : @buslane.HandlerTable,
) -> @buslane.HandlerTable {
  {
    handled_effect: self.remap_effect(object, table.handled_effect),
    operations: table.operations.map(fn(alternative) {
      self.remap_operation_alternative(object, alternative)
    }),
  }
}

///|
fn BuslaneLinker::remap_operation_alternative(
  self : BuslaneLinker,
  object : LinkModuleObject,
  alternative : @buslane.OperationAlternative,
) -> @buslane.OperationAlternative {
  {
    operation: self.remap_operation_id(object, alternative.operation),
    type_binders: alternative.type_binders.map(fn(id) {
      self.remap_type_parameter_id(object, id)
    }),
    payload_binders: alternative.payload_binders.map(fn(id) {
      self.remap_value_id(object, id)
    }),
    resume_binder: self.remap_value_id(object, alternative.resume_binder),
    body: self.remap_expr(object, alternative.body),
  }
}

///|
fn BuslaneLinker::remap_alt_constructor(
  self : BuslaneLinker,
  object : LinkModuleObject,
  alt_constructor : @buslane.AltCon,
) -> @buslane.AltCon {
  match alt_constructor {
    Default => Default
    Literal(literal) => Literal(literal)
    DataCon(id) => DataCon(self.remap_data_constructor_id(object, id))
  }
}

///|
fn BuslaneLinker::remap_type(
  self : BuslaneLinker,
  object : LinkModuleObject,
  type_ : @buslane.Type,
) -> @buslane.Type {
  match type_ {
    Primitive(primitive) => Primitive(primitive)
    Parameter(id) => Parameter(self.remap_type_parameter_id(object, id))
    Constructor(id) => Constructor(self.remap_type_id(object, id))
    Apply(callee, arguments) =>
      Apply(
        self.remap_type(object, callee),
        arguments.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_type(object, body),
      )
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { self.remap_type(object, parameter) }),
        self.remap_type(object, result),
        self.remap_effect(object, effect),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
        self.remap_type(object, body),
      )
  }
}

///|
fn BuslaneLinker::remap_generic_argument(
  self : BuslaneLinker,
  object : LinkModuleObject,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(self.remap_type(object, type_))
    EffectArgument(effect) => EffectArgument(self.remap_effect(object, effect))
  }
}

///|
fn BuslaneLinker::remap_effect(
  self : BuslaneLinker,
  object : LinkModuleObject,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  match effect {
    Empty => Empty
    Io => Io
    Singleton(id, arguments) =>
      Singleton(
        self.remap_effect_id(object, id),
        arguments.map(fn(argument) {
          self.remap_generic_argument(object, argument)
        }),
      )
    Parameter(parameter) =>
      Parameter(self.remap_type_parameter_id(object, parameter))
    Union(effects) =>
      Union(effects.map(fn(effect) { self.remap_effect(object, effect) }))
  }
}

///|
fn BuslaneLinker::remap_type_parameter_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  if self.identities.find_type_parameter(object.module_path_text, source)
    is Some(target) {
    return target
  }
  guard object.metadata.type_parameter_info(source) is Some(info) else {
    abort("unknown Buslane type parameter id")
  }
  let target = self.metadata.define_type_parameter(
    info.name.occurrence,
    info.kind,
  )
  self.identities.bind_type_parameter(object.module_path_text, source, target)
}

///|
fn BuslaneLinker::remap_type_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.TypeId,
) -> @buslane.TypeId {
  if self.identities.find_type(object.module_path_text, source) is Some(target) {
    return target
  }
  guard object.metadata.type_info(source) is Some(info) else {
    abort("unknown Buslane type id")
  }
  let target = self.metadata.define_type(
    info.name.occurrence,
    info.parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
  )
  ignore(self.identities.bind_type(object.module_path_text, source, target))
  for data_constructor in info.constructors {
    ignore(self.remap_data_constructor_id(object, data_constructor))
  }
  target
}

///|
fn BuslaneLinker::remap_effect_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.EffectId,
) -> @buslane.EffectId {
  if self.identities.find_effect(object.module_path_text, source)
    is Some(target) {
    return target
  }
  guard object.metadata.effect_info(source) is Some(info) else {
    abort("unknown Buslane effect id")
  }
  let target = self.metadata.define_effect(
    info.name.occurrence,
    info.parameters.map(fn(id) { self.remap_type_parameter_id(object, id) }),
  )
  ignore(self.identities.bind_effect(object.module_path_text, source, target))
  for operation in info.operations {
    ignore(self.remap_operation_id(object, operation))
  }
  target
}

///|
fn BuslaneLinker::remap_operation_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.OperationId,
) -> @buslane.OperationId {
  if self.identities.find_operation(object.module_path_text, source)
    is Some(target) {
    return target
  }
  guard object.metadata.operation_info(source) is Some(info) else {
    abort("unknown Buslane operation id")
  }
  let owner = self.remap_effect_id(object, info.owner)
  if self.identities.find_operation(object.module_path_text, source)
    is Some(target) {
    return target
  }
  let target = self.metadata.define_operation(
    info.name.occurrence,
    owner,
    info.hidden_type_parameters.map(fn(id) {
      self.remap_type_parameter_id(object, id)
    }),
    info.payload_types.map(fn(type_) { self.remap_type(object, type_) }),
    self.remap_type(object, info.result_type),
  )
  self.identities.bind_operation(object.module_path_text, source, target)
}

///|
fn BuslaneLinker::remap_value_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.ValueId,
) -> @buslane.ValueId {
  if self.identities.find_value(object.module_path_text, source) is Some(target) {
    return target
  }
  guard object.metadata.value_info(source) is Some(info) else {
    abort("unknown Buslane value id")
  }
  let target = self.metadata.define_value(
    info.name.occurrence,
    info.kind,
    self.remap_type(object, info.type_),
  )
  self.identities.bind_value(object.module_path_text, source, target)
}

///|
fn BuslaneLinker::remap_data_constructor_id(
  self : BuslaneLinker,
  object : LinkModuleObject,
  source : @buslane.DataConId,
) -> @buslane.DataConId {
  if self.identities.find_data_constructor(object.module_path_text, source)
    is Some(target) {
    return target
  }
  guard object.metadata.data_constructor_info(source) is Some(info) else {
    abort("unknown Buslane data constructor id")
  }
  let owner = self.remap_type_id(object, info.owner)
  if self.identities.find_data_constructor(object.module_path_text, source)
    is Some(target) {
    return target
  }
  let target = self.metadata.define_data_constructor(
    info.name.occurrence,
    owner,
    info.hidden_type_parameters.map(fn(id) {
      self.remap_type_parameter_id(object, id)
    }),
    info.payload_types.map(fn(type_) { self.remap_type(object, type_) }),
  )
  self.identities.bind_data_constructor(object.module_path_text, source, target)
}
