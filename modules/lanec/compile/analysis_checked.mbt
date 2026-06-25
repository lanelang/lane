///|
fn collect_checked_source_analysis(
  source_id : String,
  source_text : String,
  source : @checked.CheckedSourceFile,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  for declaration in source.declarations {
    collect_checked_top_level_declaration(
      source_id, source_text, declaration, definitions, references, hovers,
    )
  }
}

///|
fn collect_checked_top_level_declaration(
  source_id : String,
  source_text : String,
  declaration : @checked.CheckedTopLevelDeclaration,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
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
          parameter.loc,
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
      )
    }
    Let(declaration) => {
      match declaration.name {
        Some(name) =>
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(declaration.symbol),
            name_span(source_text, name, declaration.loc),
            name,
            name + " : " + type_text(declaration.type_),
          )
        None => ()
      }
      collect_checked_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
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
) -> Unit {
  match item {
    Let(declaration) => {
      match declaration.name {
        Some(name) =>
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(declaration.symbol),
            name_span(source_text, name, declaration.loc),
            name,
            name + " : " + type_text(declaration.type_),
          )
        None => ()
      }
      collect_checked_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
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
      )
      collect_checked_pattern(
        source_id,
        source_text,
        declaration.pattern,
        definitions,
        references,
        hovers,
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
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          parameter.loc,
          parameter.name,
          parameter.name + " : " + type_text(parameter.type_),
        )
      }
      collect_checked_expr(
        source_id, source_text, body, definitions, references, hovers,
      )
    }
    TypeApplication(callee~, ..) =>
      collect_checked_expr(
        source_id, source_text, callee, definitions, references, hovers,
      )
    Block(items~, result~, ..) => {
      for item in items {
        collect_checked_local_item(
          source_id, source_text, item, definitions, references, hovers,
        )
      }
      collect_checked_expr(
        source_id, source_text, result, definitions, references, hovers,
      )
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_checked_expr(
        source_id, source_text, condition, definitions, references, hovers,
      )
      collect_checked_expr(
        source_id, source_text, then_branch, definitions, references, hovers,
      )
      collect_checked_expr(
        source_id, source_text, else_branch, definitions, references, hovers,
      )
    }
    Match(scrutinee~, arms~, ..) => {
      collect_checked_expr(
        source_id, source_text, scrutinee, definitions, references, hovers,
      )
      for arm in arms {
        collect_checked_pattern(
          source_id,
          source_text,
          arm.pattern,
          definitions,
          references,
          hovers,
        )
        collect_checked_expr(
          source_id,
          source_text,
          arm.body,
          definitions,
          references,
          hovers,
        )
      }
    }
    Call(callee~, arguments~, ..) => {
      collect_checked_expr(
        source_id, source_text, callee, definitions, references, hovers,
      )
      for argument in arguments {
        collect_checked_expr(
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    }
    Field(base~, field~, name~, type_~, loc~) => {
      collect_checked_expr(
        source_id, source_text, base, definitions, references, hovers,
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
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    }
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
) -> Unit {
  match pattern {
    Wildcard(..) | Literal(..) => ()
    Binding(name~, symbol~, type_~, loc~) =>
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(symbol),
        loc,
        name,
        name + " : " + type_text(type_),
      )
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
          source_id, source_text, argument, definitions, references, hovers,
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
        )
      }
    }
  }
}
