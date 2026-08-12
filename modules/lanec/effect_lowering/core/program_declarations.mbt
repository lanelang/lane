// Effect lowering rewrites declarations into a form later stages require. A
// declaration the program does not mention is not part of that contract: it was
// legal Buslane on the way in and stays legal untouched, whereas rewriting only
// the types under it and not the binders that scope them makes it illegal.
//
// Effect specialization is where such declarations come from. It drops the
// terms of a definition it has copied and keeps the definition's metadata.

///|
/// The declarations a program mentions.
pub(all) struct ProgramDeclarations {
  priv metadata : @buslane.MetadataRegistry
  priv value_ids : Array[@buslane.ValueId]
  priv type_ids : Array[@buslane.TypeId]
  priv data_constructor_ids : Array[@buslane.DataConId]
  priv seen_values : Array[Bool]
  priv seen_types : Array[Bool]
  priv seen_data_constructors : Array[Bool]
}

///|
pub fn ProgramDeclarations::value_ids(
  self : ProgramDeclarations,
) -> Array[@buslane.ValueId] {
  self.value_ids.copy()
}

///|
pub fn ProgramDeclarations::data_constructor_ids(
  self : ProgramDeclarations,
) -> Array[@buslane.DataConId] {
  self.data_constructor_ids.copy()
}

///|
pub fn ProgramDeclarations::type_ids(
  self : ProgramDeclarations,
) -> Array[@buslane.TypeId] {
  self.type_ids.copy()
}

///|
/// Collects every value and transitive nominal declaration the program names.
pub fn collect_program_declarations(program : Program) -> ProgramDeclarations {
  let declarations = ProgramDeclarations::{
    metadata: program.metadata,
    value_ids: [],
    type_ids: [],
    data_constructor_ids: [],
    seen_values: Array::make(program.metadata.values.length(), false),
    seen_types: Array::make(program.metadata.types.length(), false),
    seen_data_constructors: Array::make(
      program.metadata.data_constructors.length(),
      false,
    ),
  }
  for term in program.terms {
    match term {
      Let(value, expression) => {
        declarations.mark_value(value)
        declarations.walk_expr(expression)
      }
      LetRec(bindings) =>
        for binding in bindings {
          declarations.mark_value(binding.id)
          declarations.walk_expr(binding.rhs)
        }
      External(value) => declarations.mark_value(value)
    }
  }
  declarations
}

///|
fn ProgramDeclarations::mark_value(
  self : ProgramDeclarations,
  value : @buslane.ValueId,
) -> Unit {
  if value.index >= 0 &&
    value.index < self.seen_values.length() &&
    !self.seen_values[value.index] {
    self.seen_values[value.index] = true
    self.value_ids.push(value)
    if self.metadata.value_info(value) is Some(info) {
      self.walk_type(info.type_)
    }
  }
}

///|
fn ProgramDeclarations::mark_type(
  self : ProgramDeclarations,
  type_id : @buslane.TypeId,
) -> Unit {
  if type_id.index >= 0 &&
    type_id.index < self.seen_types.length() &&
    !self.seen_types[type_id.index] {
    self.seen_types[type_id.index] = true
    self.type_ids.push(type_id)
    if self.metadata.type_info(type_id) is Some(info) {
      for data_constructor in info.constructors {
        self.mark_data_constructor(data_constructor)
      }
    }
  }
}

///|
fn ProgramDeclarations::mark_data_constructor(
  self : ProgramDeclarations,
  data_constructor : @buslane.DataConId,
) -> Unit {
  if data_constructor.index >= 0 &&
    data_constructor.index < self.seen_data_constructors.length() &&
    !self.seen_data_constructors[data_constructor.index] {
    self.seen_data_constructors[data_constructor.index] = true
    self.data_constructor_ids.push(data_constructor)
    if self.metadata.data_constructor_info(data_constructor) is Some(info) {
      self.mark_type(info.owner)
      for payload_type in info.payload_types {
        self.walk_type(payload_type)
      }
    }
  }
}

///|
fn ProgramDeclarations::walk_type(
  self : ProgramDeclarations,
  type_ : @buslane.Type,
) -> Unit {
  match type_ {
    Primitive(_) | Parameter(_) => ()
    Constructor(type_id) => self.mark_type(type_id)
    Apply(callee, arguments) => {
      self.walk_type(callee)
      for argument in arguments {
        self.walk_generic_argument(argument)
      }
    }
    TypeLambda(_, body) | Forall(_, body) => self.walk_type(body)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.walk_type(parameter)
      }
      self.walk_type(result)
      self.walk_effect(effect)
    }
  }
}

///|
fn ProgramDeclarations::walk_generic_argument(
  self : ProgramDeclarations,
  argument : @buslane.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.walk_type(type_)
    EffectArgument(effect) => self.walk_effect(effect)
  }
}

///|
fn ProgramDeclarations::walk_effect(
  self : ProgramDeclarations,
  effect : @buslane.Effect,
) -> Unit {
  match effect {
    Empty | Builtin(_) | Parameter(_) => ()
    Singleton(_, arguments) =>
      for argument in arguments {
        self.walk_generic_argument(argument)
      }
    Union(effects) =>
      for effect in effects {
        self.walk_effect(effect)
      }
  }
}

///|
fn ProgramDeclarations::walk_function(
  self : ProgramDeclarations,
  function : FunctionExpr,
) -> Unit {
  for parameter in function.parameters {
    self.mark_value(parameter)
  }
  self.walk_expr(function.body)
}

///|
fn ProgramDeclarations::walk_expr(
  self : ProgramDeclarations,
  expression : Expr,
) -> Unit {
  match expression {
    Ref(value) => self.mark_value(value)
    Literal(_) => ()
    Function(function) => self.walk_function(function)
    Call(callee, arguments) => {
      self.walk_expr(callee)
      for argument in arguments {
        self.walk_expr(argument)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) => self.walk_expr(body)
    Construct(construct) => {
      self.mark_data_constructor(construct.data_constructor)
      for payload in construct.payloads {
        self.walk_expr(payload)
      }
    }
    Let(value, initializer, body) => {
      self.mark_value(value)
      self.walk_expr(initializer)
      self.walk_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.mark_value(binding.id)
        self.walk_expr(binding.rhs)
      }
      self.walk_expr(body)
    }
    Match(match_) => {
      self.mark_value(match_.binder)
      self.walk_expr(match_.scrutinee)
      for alternative in match_.alternatives {
        if alternative.alt_constructor is DataCon(data_constructor) {
          self.mark_data_constructor(data_constructor)
        }
        for binder in alternative.value_binders {
          self.mark_value(binder)
        }
        self.walk_expr(alternative.body)
      }
    }
    Invoke(invoke) =>
      for payload in invoke.payloads {
        self.walk_expr(payload)
      }
    Install(install) => {
      self.walk_expr(install.body)
      self.walk_function(install.final_clause)
      for dictionary in install.dictionaries {
        for clause in dictionary.operations {
          match clause.callable {
            Monomorphic(function) => self.walk_function(function)
            Polymorphic(_, function) => self.walk_function(function)
          }
        }
      }
    }
    Bind(bind) => {
      self.mark_value(bind.binder)
      self.walk_expr(bind.computation)
      self.walk_function(bind.continuation)
    }
    OpenContext(open) => self.walk_expr(open.body)
  }
}
