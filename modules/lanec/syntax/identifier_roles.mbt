///|
/// The grammatical role of an identifier-shaped syntax leaf.
pub(all) enum SyntacticIdentifierRole {
  TypeIdentifier
  EffectIdentifier
  ValueIdentifier
  PatternIdentifier
} derive(Debug, Eq)

///|
priv struct SyntacticIdentifierSlot {
  span : @basic.SourceSpan
  role : SyntacticIdentifierRole
} derive(Debug, Eq)

///|
/// An immutable source-position index over grammatical identifier roles.
pub struct SyntacticIdentifierIndex {
  priv slots : Array[SyntacticIdentifierSlot]
} derive(Debug, Eq)

///|
/// Builds the identifier-role index for a parsed source file.
pub fn SourceFile::syntactic_identifier_index(
  self : SourceFile,
) -> SyntacticIdentifierIndex {
  let slots = []
  for declaration in self.declarations {
    collect_declaration_identifier_roles(declaration, slots)
  }
  SyntacticIdentifierIndex::from_slots(slots)
}

///|
fn SyntacticIdentifierIndex::from_slots(
  slots : Array[SyntacticIdentifierSlot],
) -> SyntacticIdentifierIndex {
  slots.sort_by(fn(left, right) {
    let start_order = left.span.start_offset.compare(right.span.start_offset)
    if start_order != 0 {
      start_order
    } else {
      left.span.end_offset.compare(right.span.end_offset)
    }
  })
  { slots, }
}

///|
pub fn SyntacticIdentifierIndex::empty() -> SyntacticIdentifierIndex {
  { slots: [] }
}

///|
pub fn SyntacticIdentifierIndex::expected_identifier(
  span : @basic.SourceSpan,
  role : SyntacticIdentifierRole,
) -> SyntacticIdentifierIndex {
  { slots: [{ span, role }] }
}

///|
/// Returns the grammatical role at a source offset, or `None` when the syntax
/// does not constrain the identifier namespace.
pub fn SyntacticIdentifierIndex::role_at(
  self : SyntacticIdentifierIndex,
  offset : Int,
) -> SyntacticIdentifierRole? {
  let mut low = 0
  let mut high = self.slots.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.slots[middle].span.start_offset <= offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  guard low > 0 else { return None }
  let slot = self.slots[low - 1]
  if offset <= slot.span.end_offset {
    Some(slot.role)
  } else {
    None
  }
}

///|
fn push_syntactic_identifier_role(
  slots : Array[SyntacticIdentifierSlot],
  span : @basic.SourceSpan,
  role : SyntacticIdentifierRole,
) -> Unit {
  slots.push({ span, role })
}

///|
fn collect_declaration_identifier_roles(
  declaration : TopLevelDeclaration,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match declaration {
    Struct(declaration) =>
      for declaration_member in declaration.members {
        if declaration_member is Field(field) {
          collect_type_identifier_roles(field.type_, TypeIdentifier, slots)
        }
      }
    Enum(declaration) =>
      for variant in declaration.variants {
        for payload in variant.payload {
          collect_type_identifier_roles(payload, TypeIdentifier, slots)
        }
      }
    Effect(declaration) =>
      for operation in declaration.operations {
        for payload in operation.payload {
          collect_type_identifier_roles(payload, TypeIdentifier, slots)
        }
        collect_type_identifier_roles(operation.result, TypeIdentifier, slots)
      }
    ExternalType(_) => ()
    TypeAlias(declaration) =>
      match declaration.body {
        TypeBody(type_) =>
          collect_type_identifier_roles(type_, TypeIdentifier, slots)
        EffectBody(effect) => collect_effect_identifier_roles(effect, slots)
      }
    Function(declaration) =>
      collect_function_identifier_roles(declaration, slots)
    Let(declaration) => collect_let_identifier_roles(declaration, slots)
  }
}

///|
fn collect_function_identifier_roles(
  declaration : FunctionDeclaration,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  for parameter in declaration.parameters {
    collect_type_identifier_roles(parameter.type_, TypeIdentifier, slots)
  }
  collect_type_identifier_roles(declaration.return_type, TypeIdentifier, slots)
  collect_effect_identifier_roles(declaration.effect, slots)
  collect_expression_identifier_roles(declaration.body, slots)
}

///|
fn collect_let_identifier_roles(
  declaration : LetDeclaration,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  if declaration.type_annotation is Some(type_) {
    collect_type_identifier_roles(type_, TypeIdentifier, slots)
  }
  collect_expression_identifier_roles(declaration.initializer, slots)
}

///|
fn collect_type_identifier_roles(
  type_ : Type,
  role : SyntacticIdentifierRole,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match type_ {
    Name(loc~, ..) | QualifiedName(loc~, ..) =>
      push_syntactic_identifier_role(slots, loc, role)
    Apply(callee~, arguments~, ..) => {
      collect_type_identifier_roles(callee, role, slots)
      for argument in arguments {
        collect_generic_argument_identifier_roles(argument, slots)
      }
    }
    TypeLambda(body~, ..) => collect_type_identifier_roles(body, role, slots)
    Function(parameters~, result~, effect~, ..) => {
      for parameter in parameters {
        collect_type_identifier_roles(parameter, TypeIdentifier, slots)
      }
      collect_type_identifier_roles(result, TypeIdentifier, slots)
      collect_effect_identifier_roles(effect, slots)
    }
    Tuple(items~, ..) =>
      for item in items {
        collect_type_identifier_roles(item, TypeIdentifier, slots)
      }
    Grouped(type_~, ..) => collect_type_identifier_roles(type_, role, slots)
  }
}

///|
fn collect_effect_identifier_roles(
  effect : EffectTerm,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match effect {
    Empty(_) => ()
    Term(type_~, ..) =>
      collect_type_identifier_roles(type_, EffectIdentifier, slots)
    Union(items~, ..) =>
      for item in items {
        collect_type_identifier_roles(item, EffectIdentifier, slots)
      }
  }
}

///|
fn collect_generic_argument_identifier_roles(
  argument : GenericArgument,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match argument {
    TypeTerm(type_) =>
      collect_type_identifier_roles(type_, TypeIdentifier, slots)
    EffectTerm(effect) => collect_effect_identifier_roles(effect, slots)
  }
}

///|
fn collect_pattern_identifier_roles(
  pattern : Pattern,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match pattern {
    Wildcard(_)
    | IntLiteral(_, ..)
    | DoubleLiteral(_, ..)
    | StringLiteral(_, ..)
    | BoolLiteral(_, ..) => ()
    Binding(_, loc~) =>
      push_syntactic_identifier_role(slots, loc, PatternIdentifier)
    QualifiedVariant(type_name_loc~, variant_loc~, arguments~, ..) => {
      push_syntactic_identifier_role(slots, type_name_loc, TypeIdentifier)
      push_syntactic_identifier_role(slots, variant_loc, PatternIdentifier)
      for argument in arguments {
        collect_pattern_identifier_roles(argument, slots)
      }
    }
    UnqualifiedVariant(variant_loc~, arguments~, ..) => {
      push_syntactic_identifier_role(slots, variant_loc, PatternIdentifier)
      for argument in arguments {
        collect_pattern_identifier_roles(argument, slots)
      }
    }
    Struct(type_name_loc~, fields~, ..) => {
      push_syntactic_identifier_role(slots, type_name_loc, TypeIdentifier)
      for field in fields {
        if field is Value(pattern=Some(pattern), ..) {
          collect_pattern_identifier_roles(pattern, slots)
        }
      }
    }
    Tuple(items~, ..) =>
      for item in items {
        collect_pattern_identifier_roles(item, slots)
      }
  }
}

///|
fn collect_expression_identifier_roles(
  expression : Expr,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match expression {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Builtin(_)
    | Extern(_) => ()
    Var(_, loc~) => push_syntactic_identifier_role(slots, loc, ValueIdentifier)
    QualifiedVariant(
      owner~,
      variant_loc~,
      variant_type_arguments~,
      arguments~,
      ..
    ) => {
      collect_type_identifier_roles(owner, TypeIdentifier, slots)
      push_syntactic_identifier_role(slots, variant_loc, ValueIdentifier)
      for argument in variant_type_arguments {
        collect_generic_argument_identifier_roles(argument, slots)
      }
      for argument in arguments {
        collect_expression_identifier_roles(argument, slots)
      }
    }
    StructLiteral(owner~, fields~, ..) => {
      collect_type_identifier_roles(owner, TypeIdentifier, slots)
      for field in fields {
        match field {
          Value(value=Some(value), ..) =>
            collect_expression_identifier_roles(value, slots)
          TypeWitness(witness~, ..) =>
            collect_type_identifier_roles(witness, TypeIdentifier, slots)
          Value(value=None, ..) => ()
        }
      }
    }
    ListLiteral(items~, ..) | TupleLiteral(items~, ..) =>
      for item in items {
        collect_expression_identifier_roles(item, slots)
      }
    FunctionLiteral(parameters~, return_type~, effect~, body~, ..) => {
      for parameter in parameters {
        if parameter.type_annotation is Some(type_) {
          collect_type_identifier_roles(type_, TypeIdentifier, slots)
        }
      }
      if return_type is Some(type_) {
        collect_type_identifier_roles(type_, TypeIdentifier, slots)
      }
      if effect is Some(effect) {
        collect_effect_identifier_roles(effect, slots)
      }
      collect_expression_identifier_roles(body, slots)
    }
    EffectOperationCall(name~, type_witnesses~, arguments~, ..) => {
      if name is Qualified(owner~, ..) {
        collect_type_identifier_roles(owner, EffectIdentifier, slots)
      }
      for witness in type_witnesses {
        collect_generic_argument_identifier_roles(witness, slots)
      }
      for argument in arguments {
        collect_expression_identifier_roles(argument, slots)
      }
    }
    TypeApplication(callee~, arguments~, ..) => {
      collect_expression_identifier_roles(callee, slots)
      for argument in arguments {
        collect_generic_argument_identifier_roles(argument, slots)
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      collect_expression_identifier_roles(body, slots)
      for handler in handlers {
        for arm in handler.arms {
          if arm.name is Qualified(owner~, ..) {
            collect_type_identifier_roles(owner, EffectIdentifier, slots)
          }
          for pattern in arm.payload_patterns {
            collect_pattern_identifier_roles(pattern, slots)
          }
          collect_expression_identifier_roles(arm.body, slots)
        }
      }
      collect_expression_identifier_roles(final_branch.body, slots)
    }
    Block(items~, result~, ..) => {
      for item in items {
        collect_local_item_identifier_roles(item, slots)
      }
      collect_expression_identifier_roles(result, slots)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_expression_identifier_roles(condition, slots)
      collect_expression_identifier_roles(then_branch, slots)
      if else_branch is Some(branch) {
        collect_expression_identifier_roles(branch, slots)
      }
    }
    Match(scrutinee~, arms~, ..) => {
      collect_expression_identifier_roles(scrutinee, slots)
      for arm in arms {
        collect_pattern_identifier_roles(arm.pattern, slots)
        collect_expression_identifier_roles(arm.body, slots)
      }
    }
    Call(callee~, arguments~, ..) => {
      collect_expression_identifier_roles(callee, slots)
      for argument in arguments {
        match argument {
          Positional(value~, ..) | Named(value~, ..) =>
            collect_expression_identifier_roles(value, slots)
        }
      }
    }
    Field(base~, ..) | Unary(operand=base, ..) | Grouped(expression=base, ..) =>
      collect_expression_identifier_roles(base, slots)
    Binary(left~, right~, ..) | Pipeline(left~, right~, ..) => {
      collect_expression_identifier_roles(left, slots)
      collect_expression_identifier_roles(right, slots)
    }
  }
}

///|
fn collect_local_item_identifier_roles(
  item : LocalItem,
  slots : Array[SyntacticIdentifierSlot],
) -> Unit {
  match item {
    Let(declaration) => collect_let_identifier_roles(declaration, slots)
    PatternLet(declaration) => {
      collect_pattern_identifier_roles(declaration.pattern, slots)
      if declaration.type_annotation is Some(type_) {
        collect_type_identifier_roles(type_, TypeIdentifier, slots)
      }
      collect_expression_identifier_roles(declaration.initializer, slots)
    }
    Function(declaration) =>
      collect_function_identifier_roles(declaration, slots)
    Expression(expression~) =>
      collect_expression_identifier_roles(expression, slots)
  }
}
