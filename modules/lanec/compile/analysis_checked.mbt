///|
priv struct CheckedAnalysisContext {
  inlay_hints : Array[InlayHintEntry]
  annotated_values : Array[@symbol.ValueSymbolId]
  parameter_signatures : Array[ParameterHintSignature]
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
    Enum(declaration) =>
      for variant in declaration.variants {
        add_parameter_hint_signature(
          signatures,
          Variant(variant.symbol),
          generated_constructor_parameters(variant.payload.length()),
        )
      }
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
    Literal(_) | Value(_) | UnsafeBuiltin(_) => ()
    FunctionLiteral(body~, ..) =>
      collect_checked_expr_parameter_signatures(body, signatures)
    TypeApplication(callee~, ..) =>
      collect_checked_expr_parameter_signatures(callee, signatures)
    Block(items~, result~, ..) => {
      for item in items {
        collect_checked_local_parameter_signatures(item, signatures)
      }
      collect_checked_expr_parameter_signatures(result, signatures)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_checked_expr_parameter_signatures(condition, signatures)
      collect_checked_expr_parameter_signatures(then_branch, signatures)
      collect_checked_expr_parameter_signatures(else_branch, signatures)
    }
    Match(scrutinee~, arms~, ..) => {
      collect_checked_expr_parameter_signatures(scrutinee, signatures)
      for arm in arms {
        collect_checked_expr_parameter_signatures(arm.body, signatures)
      }
    }
    Call(callee~, arguments~, ..) => {
      collect_checked_expr_parameter_signatures(callee, signatures)
      for argument in arguments {
        collect_checked_expr_parameter_signatures(argument, signatures)
      }
    }
    Field(base~, ..) =>
      collect_checked_expr_parameter_signatures(base, signatures)
    StructLiteral(fields~, ..) =>
      for field in fields {
        collect_checked_expr_parameter_signatures(field.value, signatures)
      }
    Variant(arguments~, ..) =>
      for argument in arguments {
        collect_checked_expr_parameter_signatures(argument, signatures)
      }
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
fn generated_constructor_parameters(
  count : Int,
) -> Array[ParameterHintParameter] {
  let parameters = []
  for index in 0..<count {
    parameters.push({ name: "arg\{index}", is_auto: false })
  }
  parameters
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
        "type " + declaration.name + " : Type",
      )
      for parameter in declaration.type_parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeParameter(parameter.id),
          name_span(source_text, parameter.name, declaration.loc),
          parameter.name,
          parameter.name + " : " + kind_text(parameter.kind),
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
          "type " + type_member.name + " : " + kind_text(type_member.kind),
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
          field.name + " : " + type_text(field.type_),
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
        "type " + declaration.name + " : Type",
      )
      for parameter in declaration.type_parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          TypeParameter(parameter.id),
          name_span(source_text, parameter.name, declaration.loc),
          parameter.name,
          parameter.name + " : " + kind_text(parameter.kind),
        )
      }
      for variant in declaration.variants {
        let payload = variant.payload.map(type_text).join(", ")
        let detail = if payload == "" {
          variant.name
        } else {
          variant.name + "(" + payload + ")"
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
    Function(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        declaration.name + " : " + type_text(declaration.type_),
      )
      for parameter in declaration.parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          name_span(source_text, parameter.name, parameter.loc),
          parameter.name,
          parameter.name + " : " + type_text(parameter.type_),
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
            name + " : " + type_text(declaration.type_),
          )
          if !context.annotated_values.contains(declaration.symbol) {
            add_type_inlay_hint(
              context.inlay_hints,
              source_id,
              name_loc,
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
            name + " : " + type_text(declaration.type_),
          )
          if !context.annotated_values.contains(declaration.symbol) {
            add_type_inlay_hint(
              context.inlay_hints,
              source_id,
              name_loc,
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
    Literal(..) | UnsafeBuiltin(..) => ()
    Value(name~, symbol~, type_~, loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        Value(symbol),
        loc,
        Some(name + " : " + type_text(type_)),
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
          parameter.name + " : " + type_text(parameter.type_),
        )
        if !context.annotated_values.contains(parameter.symbol) {
          add_type_inlay_hint(
            context.inlay_hints,
            source_id,
            name_loc,
            parameter.type_,
          )
        }
      }
      collect_checked_expr(
        source_id, source_text, body, definitions, references, hovers, context,
      )
    }
    TypeApplication(callee~, ..) =>
      collect_checked_expr(
        source_id, source_text, callee, definitions, references, hovers, context,
      )
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
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_checked_expr(
        source_id, source_text, condition, definitions, references, hovers, context,
      )
      collect_checked_expr(
        source_id, source_text, then_branch, definitions, references, hovers, context,
      )
      collect_checked_expr(
        source_id, source_text, else_branch, definitions, references, hovers, context,
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
          source_id, source_text, argument, definitions, references, hovers, context,
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
        Some(name + " : " + type_text(type_)),
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
        Some("type " + @prettyprinter.render(symbol.pretty(), width=80)),
      )
      for witness in type_witnesses {
        add_reference(
          references,
          hovers,
          source_id,
          TypeMember(witness.symbol),
          witness.loc,
          Some(witness.name + " = " + type_text(witness.type_)),
        )
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
      add_variant_parameter_name_hints(
        context.inlay_hints,
        source_id,
        symbol,
        arguments,
        context,
      )
      for argument in arguments {
        collect_checked_expr(
          source_id, source_text, argument, definitions, references, hovers, context,
        )
      }
    }
  }
}

///|
fn add_call_inlay_hints(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  callee : @checked.CheckedExpr,
  arguments : Array[@checked.CheckedExpr],
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
    TypeApplication(callee~, ..) => callee_origin_loc(callee)
    _ => callee.loc()
  }
}

///|
fn add_variant_parameter_name_hints(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  symbol : @symbol.VariantSymbolId,
  arguments : Array[@checked.CheckedExpr],
  context : CheckedAnalysisContext,
) -> Unit {
  match
    parameter_names_for_symbol(Variant(symbol), context.parameter_signatures) {
    Some(parameters) =>
      add_argument_inlay_hints(
        inlay_hints,
        source_id,
        arguments,
        parameters,
        loc_for_arguments(arguments),
        false,
      )
    None => ()
  }
}

///|
fn add_argument_inlay_hints(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  arguments : Array[@checked.CheckedExpr],
  parameters : Array[ParameterHintParameter],
  call_loc : @basic.SourceSpan,
  skip_parameter_hints : Bool,
) -> Unit {
  let count = if arguments.length() < parameters.length() {
    arguments.length()
  } else {
    parameters.length()
  }
  for index in 0..<count {
    let argument = arguments[index]
    let parameter = parameters[index]
    if parameter.is_auto && !call_loc.contains_span(argument.loc()) {
      match implicit_argument_name(argument) {
        Some(name) =>
          add_implicit_argument_inlay_hint(
            inlay_hints,
            source_id,
            call_loc,
            parameter.name,
            name,
          )
        None => ()
      }
    } else if !skip_parameter_hints && !parameter.is_auto {
      add_parameter_inlay_hint(
        inlay_hints,
        source_id,
        argument.loc(),
        parameter.name,
      )
    }
  }
}

///|
fn parameter_names_for_callee(
  callee : @checked.CheckedExpr,
  signatures : Array[ParameterHintSignature],
) -> Array[ParameterHintParameter]? {
  match callee {
    Value(symbol~, ..) => parameter_names_for_symbol(Value(symbol), signatures)
    TypeApplication(callee~, ..) =>
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
        Some(base) => Some(base + "." + name)
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
fn loc_for_arguments(
  arguments : Array[@checked.CheckedExpr],
) -> @basic.SourceSpan {
  match arguments.get(0) {
    Some(argument) => argument.loc()
    None => @basic.SourceSpan::dummy()
  }
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
        name + " : " + type_text(type_),
      )
      if !context.annotated_values.contains(symbol) {
        add_type_inlay_hint(context.inlay_hints, source_id, loc, type_)
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
        Some("type " + symbol.pretty().to_string()),
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
              parameter.name + " : " + kind_text(parameter.kind),
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
