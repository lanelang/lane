///|
priv struct CheckedAnalysisContext {
  inlay_hints : Array[InlayHintEntry]
  annotated_values : Array[@symbol.ValueSymbolId]
  parameter_signatures : Array[ParameterHintSignature]
  operation_details : Array[OperationDetail]
  display : @typecheck.TypeDisplayContext
}

///|
priv struct OperationDetail {
  symbol : @symbol.OperationSymbolId
  name : String
  detail : String
}

///|
priv struct ParameterHintSignature {
  symbol : AnalysisSymbol
  parameters : Array[ParameterHintParameter]
}

///|
priv struct ParameterHintParameter {
  name : String
  is_auto : Bool
}

///|
fn collect_checked_source_analysis(
  source_id : String,
  source_text : String,
  source : @checked.CheckedSourceFile,
  display : @typecheck.TypeDisplayContext,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  inlay_hints : Array[InlayHintEntry],
  annotated_values : Array[@symbol.ValueSymbolId],
) -> Unit {
  let context = {
    inlay_hints,
    annotated_values,
    parameter_signatures: checked_parameter_hint_signatures(source),
    operation_details: checked_operation_details(source, display),
    display,
  }
  for declaration in source.declarations {
    collect_checked_top_level_declaration(
      source_id, source_text, declaration, definitions, references, hovers, context,
    )
  }
}

///|
fn checked_parameter_hint_signatures(
  source : @checked.CheckedSourceFile,
) -> Array[ParameterHintSignature] {
  let signatures = []
  for declaration in source.declarations {
    collect_checked_top_level_parameter_signatures(declaration, signatures)
  }
  signatures
}

///|
fn checked_operation_details(
  source : @checked.CheckedSourceFile,
  display : @typecheck.TypeDisplayContext,
) -> Array[OperationDetail] {
  let details = []
  for declaration in source.declarations {
    if declaration is Effect(effect) {
      for operation in effect.operations {
        details.push({
          symbol: operation.symbol,
          name: operation.name,
          detail: checked_operation_detail(effect.name, operation, display),
        })
      }
    }
  }
  details
}

///|
fn collect_checked_top_level_parameter_signatures(
  declaration : @checked.CheckedTopLevelDeclaration,
  signatures : Array[ParameterHintSignature],
) -> Unit {
  match declaration {
    Function(declaration) => {
      add_parameter_hint_signature(
        signatures,
        Value(declaration.symbol),
        declaration.parameters.map(checked_parameter_hint_parameter),
      )
      collect_checked_expr_parameter_signatures(declaration.body, signatures)
    }
    Enum(_) | Effect(_) | ExternalType(_) => ()
    Let(declaration) =>
      collect_checked_expr_parameter_signatures(
        declaration.initializer,
        signatures,
      )
    Struct(_) => ()
  }
}

///|
fn collect_checked_local_parameter_signatures(
  item : @checked.CheckedLocalItem,
  signatures : Array[ParameterHintSignature],
) -> Unit {
  match item {
    Function(declaration) =>
      collect_checked_top_level_parameter_signatures(
        Function(declaration),
        signatures,
      )
    Let(declaration) =>
      collect_checked_expr_parameter_signatures(
        declaration.initializer,
        signatures,
      )
    PatternLet(declaration) =>
      collect_checked_expr_parameter_signatures(
        declaration.initializer,
        signatures,
      )
  }
}

///|
fn collect_checked_expr_parameter_signatures(
  expr : @checked.CheckedExpr,
  signatures : Array[ParameterHintSignature],
) -> Unit {
  match expr {
    Literal(_) | Value(_) | CompilerIntrinsic(_) | ExternBinding(_) => ()
    Block(items~, result~, ..) => {
      for item in items {
        collect_checked_local_parameter_signatures(item, signatures)
      }
      collect_checked_expr_parameter_signatures(result, signatures)
    }
    _ =>
      expr.for_each_child_expr(fn(child) {
        collect_checked_expr_parameter_signatures(child, signatures)
      })
  }
}

///|
fn add_parameter_hint_signature(
  signatures : Array[ParameterHintSignature],
  symbol : AnalysisSymbol,
  parameters : Array[ParameterHintParameter],
) -> Unit {
  if !parameters.is_empty() {
    signatures.push({ symbol, parameters })
  }
}

///|
fn checked_parameter_hint_parameter(
  parameter : @checked.CheckedValueParameter,
) -> ParameterHintParameter {
  { name: parameter.name, is_auto: parameter.is_auto }
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
fn type_member_detail(
  name : String,
  kind : @types.Kind,
  display : @typecheck.TypeDisplayContext,
) -> String {
  "type \{name} : \{display.kind_text(kind)}"
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
fn collect_checked_top_level_declaration(
  source_id : String,
  source_text : String,
  declaration : @checked.CheckedTopLevelDeclaration,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  context : CheckedAnalysisContext,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Type(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        "type \{declaration.name} : Type",
      )
      for parameter in declaration.type_parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeParameter(parameter.id),
          name_span(source_text, parameter.name, declaration.loc),
          parameter.name,
          type_parameter_detail(parameter, context.display),
        )
      }
      for type_member in declaration.type_members {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeMember(type_member.symbol),
          name_span(source_text, type_member.name, type_member.loc),
          type_member.name,
          type_member_detail(
            type_member.name,
            type_member.kind,
            context.display,
          ),
        )
      }
      for field in declaration.fields {
        add_definition(
          definitions,
          hovers,
          source_id,
          Field(field.symbol),
          name_span(source_text, field.name, field.loc),
          field.name,
          field_detail(field.name, field.type_, context.display),
        )
      }
    }
    Enum(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Type(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        "type \{declaration.name} : Type",
      )
      for parameter in declaration.type_parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeParameter(parameter.id),
          name_span(source_text, parameter.name, declaration.loc),
          parameter.name,
          type_parameter_detail(parameter, context.display),
        )
      }
      for variant in declaration.variants {
        let payload = variant.payload
          .map(fn(type_) { context.display.type_text(type_) })
          .join(", ")
        let detail = if payload == "" {
          variant.name
        } else {
          "\{variant.name}(\{payload})"
        }
        add_definition(
          definitions,
          hovers,
          source_id,
          Variant(variant.symbol),
          name_span(source_text, variant.name, variant.loc),
          variant.name,
          detail,
        )
      }
    }
    ExternalType(declaration) =>
      add_definition(
        definitions,
        hovers,
        source_id,
        Type(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        "extern type \{declaration.name} : Type",
      )
    Effect(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Effect(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        checked_effect_detail(declaration, context.display),
      )
      for parameter in declaration.type_parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeParameter(parameter.id),
          name_span(source_text, parameter.name, declaration.loc),
          parameter.name,
          type_parameter_detail(parameter, context.display),
        )
      }
      for operation in declaration.operations {
        add_definition(
          definitions,
          hovers,
          source_id,
          Operation(operation.symbol),
          name_span(source_text, operation.name, operation.loc),
          operation.name,
          checked_operation_detail(declaration.name, operation, context.display),
        )
        for parameter in operation.type_parameters {
          add_definition(
            definitions,
            hovers,
            source_id,
            TypeParameter(parameter.id),
            name_span(source_text, parameter.name, operation.loc),
            parameter.name,
            type_parameter_detail(parameter, context.display),
          )
        }
      }
    }
    Function(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        value_detail(declaration.name, declaration.type_, context.display),
      )
      for parameter in declaration.parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          name_span(source_text, parameter.name, parameter.loc),
          parameter.name,
          value_detail(parameter.name, parameter.type_, context.display),
        )
      }
      collect_checked_expr(
        source_id,
        source_text,
        declaration.body,
        definitions,
        references,
        hovers,
        context,
      )
    }
    Let(declaration) => {
      match declaration.name {
        Some(name) => {
          let name_loc = name_span(source_text, name, declaration.loc)
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(declaration.symbol),
            name_loc,
            name,
            value_detail(name, declaration.type_, context.display),
          )
          if !context.annotated_values.contains(declaration.symbol) {
            add_type_inlay_hint(
              context.inlay_hints,
              source_id,
              name_loc,
              context.display,
              declaration.type_,
            )
          }
        }
        None => ()
      }
      collect_checked_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
        context,
      )
    }
  }
}

///|
fn collect_checked_local_item(
  source_id : String,
  source_text : String,
  item : @checked.CheckedLocalItem,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  context : CheckedAnalysisContext,
) -> Unit {
  match item {
    Let(declaration) => {
      match declaration.name {
        Some(name) => {
          let name_loc = name_span(source_text, name, declaration.loc)
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(declaration.symbol),
            name_loc,
            name,
            value_detail(name, declaration.type_, context.display),
          )
          if !context.annotated_values.contains(declaration.symbol) {
            add_type_inlay_hint(
              context.inlay_hints,
              source_id,
              name_loc,
              context.display,
              declaration.type_,
            )
          }
        }
        None => ()
      }
      collect_checked_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
        context,
      )
    }
    PatternLet(declaration) => {
      collect_checked_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
        context,
      )
      collect_checked_pattern(
        source_id,
        source_text,
        declaration.pattern,
        definitions,
        references,
        hovers,
        context,
      )
    }
    Function(declaration) =>
      collect_checked_top_level_declaration(
        source_id,
        source_text,
        Function(declaration),
        definitions,
        references,
        hovers,
        context,
      )
  }
}

///|
fn collect_checked_expr(
  source_id : String,
  source_text : String,
  expr : @checked.CheckedExpr,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  context : CheckedAnalysisContext,
) -> Unit {
  match expr {
    Literal(..) | CompilerIntrinsic(..) | ExternBinding(..) => ()
    Value(name~, symbol~, type_~, loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        Value(symbol),
        loc,
        Some(value_detail(name, type_, context.display)),
      )
    FunctionLiteral(parameters~, body~, ..) => {
      for parameter in parameters {
        let name_loc = name_span(source_text, parameter.name, parameter.loc)
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          name_loc,
          parameter.name,
          value_detail(parameter.name, parameter.type_, context.display),
        )
        if !context.annotated_values.contains(parameter.symbol) {
          add_type_inlay_hint(
            context.inlay_hints,
            source_id,
            name_loc,
            context.display,
            parameter.type_,
          )
        }
      }
      collect_checked_expr(
        source_id, source_text, body, definitions, references, hovers, context,
      )
    }
    Block(items~, result~, ..) => {
      for item in items {
        collect_checked_local_item(
          source_id, source_text, item, definitions, references, hovers, context,
        )
      }
      collect_checked_expr(
        source_id, source_text, result, definitions, references, hovers, context,
      )
    }
    Match(scrutinee~, arms~, ..) => {
      collect_checked_expr(
        source_id, source_text, scrutinee, definitions, references, hovers, context,
      )
      for arm in arms {
        collect_checked_pattern(
          source_id,
          source_text,
          arm.pattern,
          definitions,
          references,
          hovers,
          context,
        )
        collect_checked_expr(
          source_id,
          source_text,
          arm.body,
          definitions,
          references,
          hovers,
          context,
        )
      }
    }
    Call(callee~, arguments~, loc~, ..) => {
      collect_checked_expr(
        source_id, source_text, callee, definitions, references, hovers, context,
      )
      add_call_inlay_hints(
        context.inlay_hints,
        source_id,
        callee,
        arguments,
        loc,
        context,
      )
      for argument in arguments {
        collect_checked_expr(
          source_id,
          source_text,
          argument.value,
          definitions,
          references,
          hovers,
          context,
        )
      }
    }
    OperationCall(operation~, arguments~, loc~, ..) => {
      add_operation_reference(
        references, hovers, source_id, source_text, operation, loc, context,
      )
      for argument in arguments {
        collect_checked_expr(
          source_id, source_text, argument, definitions, references, hovers, context,
        )
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      if body is Some(body) {
        collect_checked_expr(
          source_id, source_text, body, definitions, references, hovers, context,
        )
      }
      for handler in handlers {
        for arm in handler.operations {
          add_operation_reference(
            references,
            hovers,
            source_id,
            source_text,
            arm.operation,
            arm.loc,
            context,
          )
          for binder in arm.type_binders {
            add_definition(
              definitions,
              hovers,
              source_id,
              TypeParameter(binder.id),
              name_span(source_text, binder.name, arm.loc),
              binder.name,
              type_parameter_detail(binder, context.display),
            )
          }
          for pattern in arm.payload_patterns {
            collect_checked_pattern(
              source_id, source_text, pattern, definitions, references, hovers, context,
            )
          }
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(arm.resume_symbol),
            arm.resume_loc,
            arm.resume_binder,
            value_detail(arm.resume_binder, arm.resume_type, context.display),
          )
          if arm.body is Some(body) {
            collect_checked_expr(
              source_id, source_text, body, definitions, references, hovers, context,
            )
          }
        }
      }
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(final_branch.binder_symbol),
        final_branch.binder_loc,
        final_branch.binder,
        value_detail(
          final_branch.binder,
          final_branch.binder_type,
          context.display,
        ),
      )
      if final_branch.body is Some(body) {
        collect_checked_expr(
          source_id, source_text, body, definitions, references, hovers, context,
        )
      }
    }
    Field(base~, field~, name~, type_~, loc~) => {
      collect_checked_expr(
        source_id, source_text, base, definitions, references, hovers, context,
      )
      add_reference(
        references,
        hovers,
        source_id,
        Field(field),
        loc,
        Some(field_detail(name, type_, context.display)),
      )
    }
    StructLiteral(symbol~, type_witnesses~, fields~, loc~, ..) => {
      let reference_loc = definition_reference_span(
        definitions,
        Type(symbol),
        source_text,
        loc,
      )
      add_reference(
        references,
        hovers,
        source_id,
        Type(symbol),
        reference_loc,
        Some(type_reference_detail(Constructor(symbol), context.display)),
      )
      for witness in type_witnesses {
        add_reference(
          references,
          hovers,
          source_id,
          TypeMember(witness.symbol),
          witness.loc,
          Some(
            type_member_witness_detail(
              witness.name,
              witness.type_,
              context.display,
            ),
          ),
        )
      }
      for field in fields {
        add_reference(
          references,
          hovers,
          source_id,
          Field(field.symbol),
          field.loc,
          Some(field_detail(field.name, field.value.type_(), context.display)),
        )
        collect_checked_expr(
          source_id,
          source_text,
          field.value,
          definitions,
          references,
          hovers,
          context,
        )
      }
    }
    Variant(symbol~, arguments~, loc~, ..) => {
      let reference_loc = match definition_label(definitions, Variant(symbol)) {
        Some(name) => name_span(source_text, name, loc)
        None => loc
      }
      add_reference(
        references,
        hovers,
        source_id,
        Variant(symbol),
        reference_loc,
        definition_detail(definitions, Variant(symbol)),
      )
      for argument in arguments {
        collect_checked_expr(
          source_id, source_text, argument, definitions, references, hovers, context,
        )
      }
    }
    _ =>
      expr.for_each_child_expr(fn(child) {
        collect_checked_expr(
          source_id, source_text, child, definitions, references, hovers, context,
        )
      })
  }
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
fn checked_operation_detail(
  owner : String,
  operation : @checked.CheckedEffectOperationDeclaration,
  display : @typecheck.TypeDisplayContext,
) -> String {
  let parameters = checked_type_parameters_text(
    operation.type_parameters,
    display,
  )
  let payload = operation.payload
    .map(fn(type_) { display.type_text(type_) })
    .join(", ")
  let result = display.type_text(operation.result)
  "operation \{owner}::\{operation.name}\{parameters}(\{payload}) -> \{result}"
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
fn add_operation_reference(
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  source_id : String,
  source_text : String,
  operation : @symbol.OperationSymbolId,
  loc : @basic.SourceSpan,
  context : CheckedAnalysisContext,
) -> Unit {
  match operation_detail(operation, context.operation_details) {
    Some(detail) =>
      add_reference(
        references,
        hovers,
        source_id,
        Operation(operation),
        operation_reference_span(source_text, operation, loc, context),
        Some(detail),
      )
    None =>
      add_reference(
        references,
        hovers,
        source_id,
        Operation(operation),
        loc,
        None,
      )
  }
}

///|
fn operation_reference_span(
  source_text : String,
  operation : @symbol.OperationSymbolId,
  fallback : @basic.SourceSpan,
  context : CheckedAnalysisContext,
) -> @basic.SourceSpan {
  match operation_name(operation, context.operation_details) {
    Some(name) => name_span(source_text, name, fallback)
    None => fallback
  }
}

///|
fn operation_detail(
  symbol : @symbol.OperationSymbolId,
  details : Array[OperationDetail],
) -> String? {
  for detail in details {
    if detail.symbol == symbol {
      return Some(detail.detail)
    }
  }
  None
}

///|
fn operation_name(
  symbol : @symbol.OperationSymbolId,
  details : Array[OperationDetail],
) -> String? {
  for detail in details {
    if detail.symbol == symbol {
      return Some(detail.name)
    }
  }
  None
}

///|
fn add_call_inlay_hints(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  callee : @checked.CheckedExpr,
  arguments : Array[@checked.CheckedCallArgument],
  call_loc : @basic.SourceSpan,
  context : CheckedAnalysisContext,
) -> Unit {
  match parameter_names_for_callee(callee, context.parameter_signatures) {
    Some(parameters) =>
      add_argument_inlay_hints(
        inlay_hints,
        source_id,
        arguments,
        parameters,
        call_loc,
        is_source_operator_call(callee, call_loc),
      )
    None => ()
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
      match implicit_argument_name(argument.value) {
        Some(name) => implicit_arguments.push("\{parameter.name}=\{name}")
        None => ()
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

///|
fn collect_checked_pattern(
  source_id : String,
  source_text : String,
  pattern : @checked.CheckedPattern,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  context : CheckedAnalysisContext,
) -> Unit {
  match pattern {
    Wildcard(..) | Literal(..) => ()
    Binding(name~, symbol~, type_~, loc~) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(symbol),
        loc,
        name,
        value_detail(name, type_, context.display),
      )
      if !context.annotated_values.contains(symbol) {
        add_type_inlay_hint(
          context.inlay_hints,
          source_id,
          loc,
          context.display,
          type_,
        )
      }
    }
    Variant(symbol~, arguments~, loc~, ..) => {
      add_reference(
        references,
        hovers,
        source_id,
        Variant(symbol),
        definition_reference_span(
          definitions,
          Variant(symbol),
          source_text,
          loc,
        ),
        definition_detail(definitions, Variant(symbol)),
      )
      for argument in arguments {
        collect_checked_pattern(
          source_id, source_text, argument, definitions, references, hovers, context,
        )
      }
    }
    Struct(symbol~, type_binders~, fields~, loc~, ..) => {
      let reference_loc = definition_reference_span(
        definitions,
        Type(symbol),
        source_text,
        loc,
      )
      add_reference(
        references,
        hovers,
        source_id,
        Type(symbol),
        reference_loc,
        Some(type_reference_detail(Constructor(symbol), context.display)),
      )
      for binder in type_binders {
        match binder.type_parameter {
          Some(parameter) =>
            add_definition(
              definitions,
              hovers,
              source_id,
              TypeParameter(parameter.id),
              binder.loc,
              parameter.name,
              type_parameter_detail(parameter, context.display),
            )
          None => ()
        }
      }
      for field in fields {
        add_reference(
          references,
          hovers,
          source_id,
          Field(field.symbol),
          field.loc,
          Some(field.name),
        )
        collect_checked_pattern(
          source_id,
          source_text,
          field.pattern,
          definitions,
          references,
          hovers,
          context,
        )
      }
    }
  }
}
