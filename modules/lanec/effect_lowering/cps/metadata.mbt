///|
priv struct CpsSourceCounts {
  types : Int
  data_constructors : Int
  values : Int
}

///|
fn rewrite_cps_source_metadata(
  schema : DictionaryCpsSchema,
  counts : CpsSourceCounts,
) -> Unit raise SynthesisError {
  for index in 0..<counts.types {
    let info = schema.metadata.types[index]
    schema.metadata.types[index] = {
      name: info.name,
      flavor: info.flavor,
      parameters: info.parameters,
      constructors: info.constructors,
    }
  }
  for index in 0..<counts.data_constructors {
    let info = schema.metadata.data_constructors[index]
    schema.metadata.data_constructors[index] = {
      name: info.name,
      owner: info.owner,
      hidden_type_parameters: info.hidden_type_parameters,
      payload_types: info.payload_types.map(type_ => schema.rewrite_type(type_)),
    }
  }
  for index in 0..<counts.values {
    let info = schema.metadata.values[index]
    schema.metadata.values[index] = {
      name: info.name,
      kind: info.kind,
      type_: schema.rewrite_type(info.type_),
    }
  }
}

///|
fn synchronize_cps_value_types(program : Program) -> Unit raise SynthesisError {
  for term in program.terms {
    match term {
      Let(id, expression) => {
        synchronize_cps_expr_value_types(program.metadata, expression)
        synchronize_cps_value_type(
          program.metadata,
          id,
          synthesize_expr_or_raise(program.metadata, expression).type_,
        )
      }
      LetRec(bindings) => {
        for binding in bindings {
          synchronize_cps_expr_value_types(program.metadata, binding.rhs)
        }
        for binding in bindings {
          synchronize_cps_value_type(
            program.metadata,
            binding.id,
            synthesize_expr_or_raise(program.metadata, binding.rhs).type_,
          )
        }
      }
      External(_) => ()
    }
  }
}

///|
fn synchronize_cps_expr_value_types(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Unit raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => ()
    Function(function) =>
      synchronize_cps_expr_value_types(metadata, function.body)
    Call(callee, arguments) => {
      synchronize_cps_expr_value_types(metadata, callee)
      for argument in arguments {
        synchronize_cps_expr_value_types(metadata, argument)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      synchronize_cps_expr_value_types(metadata, body)
    Construct(construct) =>
      for payload in construct.payloads {
        synchronize_cps_expr_value_types(metadata, payload)
      }
    Let(id, initializer, body) => {
      synchronize_cps_expr_value_types(metadata, initializer)
      synchronize_cps_value_type(
        metadata,
        id,
        synthesize_expr_or_raise(metadata, initializer).type_,
      )
      synchronize_cps_expr_value_types(metadata, body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        synchronize_cps_expr_value_types(metadata, binding.rhs)
      }
      for binding in bindings {
        synchronize_cps_value_type(
          metadata,
          binding.id,
          synthesize_expr_or_raise(metadata, binding.rhs).type_,
        )
      }
      synchronize_cps_expr_value_types(metadata, body)
    }
    Match(match_) => {
      synchronize_cps_expr_value_types(metadata, match_.scrutinee)
      for alternative in match_.alternatives {
        synchronize_cps_expr_value_types(metadata, alternative.body)
      }
    }
    Invoke(invoke) =>
      for payload in invoke.payloads {
        synchronize_cps_expr_value_types(metadata, payload)
      }
    Install(install) => {
      synchronize_cps_expr_value_types(metadata, install.body)
      synchronize_cps_expr_value_types(metadata, install.final_clause.body)
      for dictionary in install.dictionaries {
        for operation in dictionary.operations {
          match operation.callable {
            Monomorphic(function) | Polymorphic(_, function) =>
              synchronize_cps_expr_value_types(metadata, function.body)
          }
        }
      }
    }
    Bind(bind) => {
      synchronize_cps_expr_value_types(metadata, bind.computation)
      synchronize_cps_expr_value_types(metadata, bind.continuation.body)
    }
    OpenContext(open) => synchronize_cps_expr_value_types(metadata, open.body)
  }
}

///|
fn synchronize_cps_value_type(
  metadata : @buslane.MetadataRegistry,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit raise SynthesisError {
  guard metadata.values.get(value.index) is Some(info) else {
    raise UnknownValue(value)
  }
  metadata.values[value.index] = { ..info, type_, }
}
