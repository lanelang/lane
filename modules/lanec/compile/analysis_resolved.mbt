///|
fn collect_resolved_source_analysis(
  source_id : String,
  source_text : String,
  source : @resolve.ResolvedSourceFile,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  for declaration in source.declarations {
    collect_resolved_top_level_declaration(
      source_id, source_text, declaration, definitions, references, hovers,
    )
  }
}

///|
fn collect_resolved_type_references(
  source_id : String,
  source_text : String,
  source : @resolve.ResolvedSourceFile,
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  let definitions : Array[DefinitionEntry] = []
  for declaration in source.declarations {
    collect_resolved_top_level_declaration(
      source_id, source_text, declaration, definitions, references, hovers,
    )
  }
}

///|
fn collect_resolved_top_level_declaration(
  source_id : String,
  source_text : String,
  declaration : @resolve.ResolvedTopLevelDeclaration,
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
        "type \{declaration.name}",
      )
      for struct_member in declaration.members {
        match struct_member {
          TypeMember(type_member) => {
            add_definition(
              definitions,
              hovers,
              source_id,
              TypeMember(type_member.symbol),
              name_span(source_text, type_member.name, type_member.loc),
              type_member.name,
              "type \{type_member.name}",
            )
            collect_resolved_type_parameter_definition(
              source_id,
              type_member.type_parameter,
              definitions,
              hovers,
            )
          }
          Field(field) => {
            add_definition(
              definitions,
              hovers,
              source_id,
              Field(field.symbol),
              name_span(source_text, field.name, field.loc),
              field.name,
              field.name,
            )
            collect_resolved_type_reference(
              source_id,
              field.type_,
              references,
              hovers,
            )
          }
        }
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
        "type \{declaration.name}",
      )
      for variant in declaration.variants {
        add_definition(
          definitions,
          hovers,
          source_id,
          Variant(variant.symbol),
          name_span(source_text, variant.name, variant.loc),
          variant.name,
          variant.name,
        )
        for payload in variant.payload {
          collect_resolved_type_reference(
            source_id, payload, references, hovers,
          )
        }
      }
    }
    TypeAlias(declaration) =>
      collect_resolved_type_reference(
        source_id,
        declaration.body,
        references,
        hovers,
      )
    Effect(declaration) => {
      for parameter in declaration.type_parameters {
        collect_resolved_type_parameter_definition(
          source_id, parameter, definitions, hovers,
        )
      }
      for operation in declaration.operations {
        for parameter in operation.type_parameters {
          collect_resolved_type_parameter_definition(
            source_id, parameter, definitions, hovers,
          )
        }
        for payload in operation.payload {
          collect_resolved_type_reference(
            source_id, payload, references, hovers,
          )
        }
        collect_resolved_type_reference(
          source_id,
          operation.result,
          references,
          hovers,
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
        declaration.name,
      )
      for parameter in declaration.parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          name_span(source_text, parameter.name, parameter.loc),
          parameter.name,
          parameter.name,
        )
        collect_resolved_type_reference(
          source_id,
          parameter.type_,
          references,
          hovers,
        )
      }
      collect_resolved_type_reference(
        source_id,
        declaration.return_type,
        references,
        hovers,
      )
      collect_resolved_expr(
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
            name,
          )
        None => ()
      }
      match declaration.type_annotation {
        Some(type_) =>
          collect_resolved_type_reference(source_id, type_, references, hovers)
        None => ()
      }
      collect_resolved_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
      )
    }
    Offer(declaration) => {
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(declaration.symbol),
        name_span(source_text, declaration.name, declaration.loc),
        declaration.name,
        declaration.name,
      )
      collect_resolved_type_reference(
        source_id,
        declaration.type_annotation,
        references,
        hovers,
      )
      collect_resolved_expr(
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
fn collect_resolved_type_parameter_definition(
  source_id : String,
  parameter : @resolve.ResolvedTypeParameter,
  definitions : Array[DefinitionEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  add_definition(
    definitions,
    hovers,
    source_id,
    TypeParameter(parameter.symbol),
    parameter.loc,
    parameter.name,
    parameter.name,
  )
}

///|
fn collect_resolved_local_item(
  source_id : String,
  source_text : String,
  item : @resolve.ResolvedLocalItem,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  match item {
    Let(declaration) =>
      collect_resolved_top_level_declaration(
        source_id,
        source_text,
        Let(declaration),
        definitions,
        references,
        hovers,
      )
    PatternLet(declaration) => {
      collect_resolved_expr(
        source_id,
        source_text,
        declaration.initializer,
        definitions,
        references,
        hovers,
      )
      collect_resolved_pattern(
        source_id,
        declaration.pattern,
        definitions,
        references,
        hovers,
      )
    }
    Function(declaration) =>
      collect_resolved_top_level_declaration(
        source_id,
        source_text,
        Function(declaration),
        definitions,
        references,
        hovers,
      )
    Offer(declaration) =>
      collect_resolved_top_level_declaration(
        source_id,
        source_text,
        Offer(declaration),
        definitions,
        references,
        hovers,
      )
  }
}

///|
fn collect_resolved_expr(
  source_id : String,
  source_text : String,
  expr : @resolve.ResolvedExpr,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  match expr {
    IntLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(..)
    | Builtin(_) => ()
    Var(name~, reference=Symbol(symbol), loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        Value(symbol),
        loc,
        Some(name),
      )
    Var(..) => ()
    QualifiedVariant(
      type_arguments~,
      variant_type_arguments~,
      reference~,
      arguments~,
      loc~,
      ..
    ) => {
      match reference {
        Symbol(symbol) => {
          let reference_loc = match
            definition_label(definitions, Variant(symbol)) {
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
        }
        _ => ()
      }
      for type_ in type_arguments {
        collect_resolved_type_reference(source_id, type_, references, hovers)
      }
      for type_ in variant_type_arguments {
        collect_resolved_type_reference(source_id, type_, references, hovers)
      }
      for argument in arguments {
        collect_resolved_expr(
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    }
    UnqualifiedVariant(reference=Symbol(symbol), arguments~, loc~, ..) => {
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
        collect_resolved_expr(
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    }
    UnqualifiedVariant(arguments~, ..) =>
      for argument in arguments {
        collect_resolved_expr(
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    StructLiteral(type_arguments~, fields~, ..) => {
      for type_ in type_arguments {
        collect_resolved_type_reference(source_id, type_, references, hovers)
      }
      for field in fields {
        match field {
          Value(value=Some(value), punned_reference~, ..) => {
            match punned_reference {
              Some(Symbol(symbol)) =>
                add_reference(
                  references,
                  hovers,
                  source_id,
                  Value(symbol),
                  resolved_expr_loc(value),
                  None,
                )
              _ => ()
            }
            collect_resolved_expr(
              source_id, source_text, value, definitions, references, hovers,
            )
          }
          Value(value=None, punned_reference=Some(Symbol(symbol)), loc~, name~) =>
            add_reference(
              references,
              hovers,
              source_id,
              Value(symbol),
              loc,
              Some(name),
            )
          Value(..) => ()
          TypeWitness(witness~, ..) =>
            collect_resolved_type_reference(
              source_id, witness, references, hovers,
            )
        }
      }
    }
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) => {
      for parameter in type_parameters {
        collect_resolved_type_parameter_definition(
          source_id, parameter, definitions, hovers,
        )
      }
      for parameter in parameters {
        add_definition(
          definitions,
          hovers,
          source_id,
          Value(parameter.symbol),
          name_span(source_text, parameter.name, parameter.loc),
          parameter.name,
          parameter.name,
        )
        match parameter.type_annotation {
          Some(type_) =>
            collect_resolved_type_reference(
              source_id, type_, references, hovers,
            )
          None => ()
        }
      }
      match return_type {
        Some(type_) =>
          collect_resolved_type_reference(source_id, type_, references, hovers)
        None => ()
      }
      collect_resolved_expr(
        source_id, source_text, body, definitions, references, hovers,
      )
    }
    Block(items~, result~, ..) => {
      for item in items {
        collect_resolved_local_item(
          source_id, source_text, item, definitions, references, hovers,
        )
      }
      collect_resolved_expr(
        source_id, source_text, result, definitions, references, hovers,
      )
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_resolved_expr(
        source_id, source_text, condition, definitions, references, hovers,
      )
      collect_resolved_expr(
        source_id, source_text, then_branch, definitions, references, hovers,
      )
      collect_resolved_expr(
        source_id, source_text, else_branch, definitions, references, hovers,
      )
    }
    Match(scrutinee~, arms~, ..) => {
      collect_resolved_expr(
        source_id, source_text, scrutinee, definitions, references, hovers,
      )
      for arm in arms {
        collect_resolved_pattern(
          source_id,
          arm.pattern,
          definitions,
          references,
          hovers,
        )
        collect_resolved_expr(
          source_id,
          source_text,
          arm.body,
          definitions,
          references,
          hovers,
        )
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      collect_resolved_expr(
        source_id, source_text, body, definitions, references, hovers,
      )
      for handler in handlers {
        for arm in handler.arms {
          collect_resolved_effect_operation_name(
            source_id,
            arm.name,
            references,
            hovers,
          )
          for pattern in arm.payload_patterns {
            collect_resolved_pattern(
              source_id, pattern, definitions, references, hovers,
            )
          }
          add_definition(
            definitions,
            hovers,
            source_id,
            Value(arm.resume_symbol),
            name_span(source_text, arm.resume_binder, arm.resume_loc),
            arm.resume_binder,
            arm.resume_binder,
          )
          collect_resolved_expr(
            source_id,
            source_text,
            arm.body,
            definitions,
            references,
            hovers,
          )
        }
      }
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(final_branch.binder_symbol),
        name_span(source_text, final_branch.binder, final_branch.binder_loc),
        final_branch.binder,
        final_branch.binder,
      )
      collect_resolved_expr(
        source_id,
        source_text,
        final_branch.body,
        definitions,
        references,
        hovers,
      )
    }
    Call(callee~, arguments~, ..) => {
      collect_resolved_expr(
        source_id, source_text, callee, definitions, references, hovers,
      )
      for argument in arguments {
        match argument {
          Positional(value) =>
            collect_resolved_expr(
              source_id, source_text, value, definitions, references, hovers,
            )
          Named(value~, ..) =>
            collect_resolved_expr(
              source_id, source_text, value, definitions, references, hovers,
            )
        }
      }
    }
    EffectOperationCall(name~, arguments~, ..) => {
      collect_resolved_effect_operation_name(
        source_id, name, references, hovers,
      )
      for argument in arguments {
        collect_resolved_expr(
          source_id, source_text, argument, definitions, references, hovers,
        )
      }
    }
    Field(base~, reference=Symbol(symbol), loc~, name~) => {
      collect_resolved_expr(
        source_id, source_text, base, definitions, references, hovers,
      )
      add_reference(
        references,
        hovers,
        source_id,
        Field(symbol),
        loc,
        Some(name),
      )
    }
    Field(base~, ..) =>
      collect_resolved_expr(
        source_id, source_text, base, definitions, references, hovers,
      )
    Unary(reference=Symbol(symbol), operand~, loc~, ..) => {
      add_reference(references, hovers, source_id, Value(symbol), loc, None)
      collect_resolved_expr(
        source_id, source_text, operand, definitions, references, hovers,
      )
    }
    Unary(operand~, ..) =>
      collect_resolved_expr(
        source_id, source_text, operand, definitions, references, hovers,
      )
    Binary(reference=Symbol(symbol), left~, right~, loc~, ..) => {
      add_reference(references, hovers, source_id, Value(symbol), loc, None)
      collect_resolved_expr(
        source_id, source_text, left, definitions, references, hovers,
      )
      collect_resolved_expr(
        source_id, source_text, right, definitions, references, hovers,
      )
    }
    Binary(left~, right~, ..) => {
      collect_resolved_expr(
        source_id, source_text, left, definitions, references, hovers,
      )
      collect_resolved_expr(
        source_id, source_text, right, definitions, references, hovers,
      )
    }
    Pipeline(left~, right~, ..) => {
      collect_resolved_expr(
        source_id, source_text, left, definitions, references, hovers,
      )
      collect_resolved_expr(
        source_id, source_text, right, definitions, references, hovers,
      )
    }
  }
}

///|
fn resolved_expr_loc(expr : @resolve.ResolvedExpr) -> @basic.SourceSpan {
  match expr {
    IntLiteral(_, loc~)
    | StringLiteral(_, loc~)
    | BoolLiteral(_, loc~)
    | UnitLiteral(loc~)
    | Var(loc~, ..)
    | QualifiedVariant(loc~, ..)
    | UnqualifiedVariant(loc~, ..)
    | StructLiteral(loc~, ..)
    | Builtin(_, loc~)
    | FunctionLiteral(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Handler(loc~, ..)
    | Call(loc~, ..)
    | EffectOperationCall(loc~, ..)
    | Field(loc~, ..)
    | Unary(loc~, ..)
    | Binary(loc~, ..)
    | Pipeline(loc~, ..) => loc
  }
}

///|
fn collect_resolved_pattern(
  source_id : String,
  pattern : @resolve.ResolvedPattern,
  definitions : Array[DefinitionEntry],
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  match pattern {
    Wildcard(_) | IntLiteral(_) | StringLiteral(_) | BoolLiteral(_) => ()
    Binding(name~, symbol~, loc~) =>
      add_definition(
        definitions,
        hovers,
        source_id,
        Value(symbol),
        loc,
        name,
        name,
      )
    QualifiedVariant(reference=Symbol(symbol), arguments~, loc~, ..) => {
      add_reference(
        references,
        hovers,
        source_id,
        Variant(symbol),
        loc,
        definition_detail(definitions, Variant(symbol)),
      )
      for argument in arguments {
        collect_resolved_pattern(
          source_id, argument, definitions, references, hovers,
        )
      }
    }
    QualifiedVariant(arguments~, ..) =>
      for argument in arguments {
        collect_resolved_pattern(
          source_id, argument, definitions, references, hovers,
        )
      }
    ShorthandVariant(arguments~, ..) =>
      for argument in arguments {
        collect_resolved_pattern(
          source_id, argument, definitions, references, hovers,
        )
      }
    Struct(fields~, ..) =>
      for field in fields {
        match field {
          Value(pattern~, ..) =>
            collect_resolved_pattern(
              source_id, pattern, definitions, references, hovers,
            )
          TypeBinder(type_parameter~, ..) =>
            collect_resolved_type_parameter_definition(
              source_id, type_parameter, definitions, hovers,
            )
          TypeWildcard(type_parameter~, ..) =>
            collect_resolved_type_parameter_definition(
              source_id, type_parameter, definitions, hovers,
            )
        }
      }
  }
}

///|
fn collect_resolved_type_reference(
  source_id : String,
  type_ : @resolve.ResolvedType,
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  match type_ {
    Primitive(_) | Alias(..) | Unresolved(..) => ()
    Constructor(symbol~, name~, loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        Type(symbol),
        loc,
        Some("type \{name}"),
      )
    Apply(callee~, arguments~, ..) => {
      collect_resolved_type_reference(source_id, callee, references, hovers)
      for argument in arguments {
        collect_resolved_type_reference(source_id, argument, references, hovers)
      }
    }
    TypeLambda(parameters~, body~, ..) => {
      for parameter in parameters {
        // Type lambda parameters are definitions inside the type expression.
        ignore(parameter)
      }
      collect_resolved_type_reference(source_id, body, references, hovers)
    }
    Parameter(symbol~, name~, loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        TypeParameter(symbol),
        loc,
        Some("type \{name}"),
      )
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      for parameter in type_parameters {
        ignore(parameter)
      }
      for parameter in parameters {
        collect_resolved_type_reference(
          source_id, parameter, references, hovers,
        )
      }
      collect_resolved_type_reference(source_id, result, references, hovers)
      collect_resolved_effect_reference(source_id, effect, references, hovers)
    }
  }
}

///|
fn collect_resolved_effect_operation_name(
  source_id : String,
  name : @resolve.ResolvedEffectOperationName,
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  if name is Qualified(owner~, ..) {
    collect_resolved_effect_reference(source_id, owner, references, hovers)
  }
}

///|
fn collect_resolved_effect_reference(
  source_id : String,
  effect : @resolve.ResolvedEffectTerm,
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
) -> Unit {
  match effect {
    Empty(..) | Unresolved(..) => ()
    Singleton(arguments~, ..) =>
      for argument in arguments {
        collect_resolved_type_reference(source_id, argument, references, hovers)
      }
    Parameter(symbol~, name~, loc~) =>
      add_reference(
        references,
        hovers,
        source_id,
        TypeParameter(symbol),
        loc,
        Some("effect \{name}"),
      )
    Union(items~, ..) =>
      for item in items {
        collect_resolved_effect_reference(source_id, item, references, hovers)
      }
  }
}
