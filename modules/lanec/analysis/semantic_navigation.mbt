///|
fn SemanticIndex::add_definition(
  self : SemanticIndex,
  symbol : AnalysisSymbol,
  span : @basic.SourceSpan,
  label : String,
  detail : String,
) -> Unit {
  add_definition(
    self.definitions,
    self.hovers,
    self.source_id,
    symbol,
    span,
    label,
    detail,
  )
}

///|
fn SemanticIndex::add_reference(
  self : SemanticIndex,
  symbol : AnalysisSymbol,
  span : @basic.SourceSpan,
  hover : String?,
) -> Unit {
  add_reference(
    self.references,
    self.hovers,
    self.source_id,
    symbol,
    span,
    hover,
  )
}

///|
fn SemanticIndex::enrich_definition(
  self : SemanticIndex,
  symbol : AnalysisSymbol,
  detail : String,
) -> Unit {
  for index, definition in self.definitions {
    if definition.symbol == symbol {
      let previous_location = definition.location
      self.definitions[index] = { ..definition, detail, }
      for hover_index, hover in self.hovers {
        if hover.location == previous_location {
          self.hovers[hover_index] = { ..hover, contents: detail }
        }
      }
    }
  }
}

///|
fn SemanticIndex::add_parameter_signature(
  self : SemanticIndex,
  symbol : @symbol.ValueSymbolId,
  parameters : Array[@resolve.ResolvedValueParameter],
) -> Unit {
  if !parameters.is_empty() {
    self.parameter_signatures.push({
      symbol: Value(symbol),
      parameters: parameters.map(fn(parameter) {
        { name: parameter.name, is_auto: parameter.is_auto }
      }),
    })
  }
}

///|
fn SemanticIndex::definition_span(
  self : SemanticIndex,
  symbol : AnalysisSymbol,
  fallback : @basic.SourceSpan,
) -> @basic.SourceSpan {
  definition_reference_span(
    self.definitions,
    symbol,
    self.source_text,
    fallback,
  )
}

///|
fn SemanticIndex::definition_detail(
  self : SemanticIndex,
  symbol : AnalysisSymbol,
) -> String? {
  definition_detail(self.definitions, symbol)
}

///|
fn SemanticIndex::add_type_inlay_hint(
  self : SemanticIndex,
  span : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
  type_ : @types.Type,
) -> Unit {
  add_type_inlay_hint(self.inlay_hints, self.source_id, span, display, type_)
}

///|
fn SemanticIndex::add_operation_reference(
  self : SemanticIndex,
  operation : @symbol.OperationSymbolId,
  fallback : @basic.SourceSpan,
) -> Unit {
  for fact in self.members {
    if fact.identity == OperationMember(operation) {
      self.add_reference(
        Operation(operation),
        name_span(self.source_text, fact.name, fallback),
        Some(fact.detail),
      )
      return
    }
  }
  self.add_reference(Operation(operation), fallback, None)
}

///|
fn SemanticIndex::add_call_inlay_hints(
  self : SemanticIndex,
  callee : @checked.CheckedExpr,
  arguments : Array[@checked.CheckedCallArgument],
  call_loc : @basic.SourceSpan,
) -> Unit {
  if parameter_names_for_callee(callee, self.parameter_signatures)
    is Some(parameters) {
    add_argument_inlay_hints(
      self.inlay_hints,
      self.source_id,
      arguments,
      parameters,
      call_loc,
      is_source_operator_call(callee, call_loc),
    )
  }
}

///|
fn value_detail(
  name : String,
  type_ : @types.Type,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "\{name} : \{display.type_text(type_)}"
}

///|
fn type_parameter_detail(
  parameter : @types.TypeParameter,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "\{parameter.name} : \{display.kind_text(parameter.kind)}"
}

///|
fn field_detail(
  name : String,
  type_ : @types.Type,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "\{name} : \{display.type_text(type_)}"
}

///|
fn type_reference_detail(
  type_ : @types.Type,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "type \{display.type_text(type_)}"
}

///|
fn type_member_witness_detail(
  name : String,
  type_ : @types.Type,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "\{name} = \{display.type_text(type_)}"
}

///|
fn checked_effect_detail(
  declaration : @checked.CheckedEffectDeclaration,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let parameters = checked_type_parameters_text(
    declaration.type_parameters,
    display,
  )
  if declaration.flavor is External {
    "extern type \{declaration.name}\{parameters} : Effect"
  } else {
    "effect \{declaration.name}\{parameters}"
  }
}

///|
fn checked_type_parameters_text(
  parameters : Array[@types.TypeParameter],
  display : @typecheck.TypeDisplayContext,
) -> String {
  if parameters.is_empty() {
    ""
  } else {
    let text = parameters
      .map(fn(parameter) { display.type_parameter_binding_text(parameter) })
      .join(", ")
    "[\{text}]"
  }
}

///|
fn is_source_operator_call(
  callee : @checked.CheckedExpr,
  call_loc : @basic.SourceSpan,
) -> Bool {
  callee_origin_loc(callee) == call_loc
}

///|
fn callee_origin_loc(callee : @checked.CheckedExpr) -> @basic.SourceSpan {
  match callee {
    GenericApplication(callee~, ..) => callee_origin_loc(callee)
    _ => callee.loc()
  }
}

///|
fn add_argument_inlay_hints(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  arguments : Array[@checked.CheckedCallArgument],
  parameters : Array[ParameterHintParameter],
  call_loc : @basic.SourceSpan,
  skip_parameter_hints : Bool,
) -> Unit {
  let count = if arguments.length() < parameters.length() {
    arguments.length()
  } else {
    parameters.length()
  }
  let implicit_arguments = []
  for index in 0..<count {
    let argument = arguments[index]
    let parameter = parameters[index]
    if parameter.is_auto && !call_loc.contains_span(argument.loc) {
      if implicit_argument_name(argument.value) is Some(name) {
        implicit_arguments.push("\{parameter.name}=\{name}")
      }
    } else if !skip_parameter_hints && !parameter.is_auto {
      add_parameter_inlay_hint(
        inlay_hints,
        source_id,
        argument.loc,
        parameter.name,
      )
    }
  }
  if !implicit_arguments.is_empty() {
    add_implicit_argument_inlay_hint(
      inlay_hints, source_id, call_loc, implicit_arguments,
    )
  }
}

///|
fn parameter_names_for_callee(
  callee : @checked.CheckedExpr,
  signatures : Array[ParameterHintSignature],
) -> Array[ParameterHintParameter]? {
  match callee {
    Value(symbol~, ..) => parameter_names_for_symbol(Value(symbol), signatures)
    GenericApplication(callee~, ..) =>
      parameter_names_for_callee(callee, signatures)
    _ => None
  }
}

///|
fn parameter_names_for_symbol(
  symbol : AnalysisSymbol,
  signatures : Array[ParameterHintSignature],
) -> Array[ParameterHintParameter]? {
  for signature in signatures {
    if signature.symbol == symbol {
      return Some(signature.parameters)
    }
  }
  None
}

///|
fn implicit_argument_name(argument : @checked.CheckedExpr) -> String? {
  match argument {
    Value(name~, ..) => Some(name)
    Field(base~, name~, ..) =>
      match implicit_argument_name(base) {
        Some(base) => Some("\{base}.\{name}")
        None => Some(name)
      }
    _ => None
  }
}

///|
fn @basic.SourceSpan::contains_span(
  self : @basic.SourceSpan,
  inner : @basic.SourceSpan,
) -> Bool {
  inner.start_offset >= self.start_offset && inner.end_offset <= self.end_offset
}
