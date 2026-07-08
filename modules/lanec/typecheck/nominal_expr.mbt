///|
fn SemanticChecker::synthesize_checked_variant_call(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String?,
  generic_arguments : Array[@resolve.ResolvedGenericArgument],
  variant : String,
  variant_generic_arguments : Array[@resolve.ResolvedGenericArgument],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match type_name {
    Some(type_name) =>
      self.synthesize_checked_qualified_variant(
        scope, type_name, generic_arguments, variant, variant_generic_arguments,
        reference, arguments, expected_result, loc,
      )
    None =>
      self.synthesize_checked_unqualified_variant(
        scope, variant, variant_generic_arguments, reference, arguments, expected_result,
        loc,
      )
  }
}

///|
fn SemanticChecker::synthesize_checked_qualified_variant(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  generic_arguments : Array[@resolve.ResolvedGenericArgument],
  variant : String,
  variant_generic_arguments : Array[@resolve.ResolvedGenericArgument],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match reference {
    Symbol(symbol) =>
      self.synthesize_checked_variant_symbol(
        scope,
        symbol,
        type_name + "::" + variant,
        generic_arguments,
        variant_generic_arguments,
        arguments,
        expected_result,
        loc,
      )
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(
          label="unresolved variant " + type_name + "::" + variant,
        ),
        loc,
      })
      checked_expression_none_reported(Error)
    }
    Ambiguous(name~, ..) => {
      self.report_ambiguous_variant_reference(name, loc)
      checked_expression_none_reported(Error)
    }
    UnresolvedUnqualified(name) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(label="unresolved variant " + name),
        loc,
      })
      checked_expression_none_reported(Error)
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_unqualified_variant(
  self : SemanticChecker,
  scope : TypeScope,
  variant : String,
  variant_generic_arguments : Array[@resolve.ResolvedGenericArgument],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match reference {
    Symbol(symbol) =>
      self.synthesize_checked_variant_symbol(
        scope,
        symbol,
        variant,
        [],
        variant_generic_arguments,
        arguments,
        expected_result,
        loc,
      )
    Ambiguous(name~, ..) => {
      self.report_ambiguous_variant_reference(name, loc)
      checked_expression_none_reported(Error)
    }
    UnresolvedUnqualified(name) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(label="unresolved variant " + name),
        loc,
      })
      checked_expression_none_reported(Error)
    }
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(
          label="unresolved variant " + type_name + "::" + variant,
        ),
        loc,
      })
      checked_expression_none_reported(Error)
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_variant_symbol(
  self : SemanticChecker,
  scope : TypeScope,
  symbol : VariantSymbolId,
  display_name : String,
  explicit_generic_arguments : Array[@resolve.ResolvedGenericArgument],
  explicit_variant_generic_arguments : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Variant construction has two generic layers: owner arguments for the enum
  // type, and variant-level hidden witnesses. Owner arguments may also use the
  // expected result type; hidden witnesses are inferred from payloads only.
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(label="unknown variant " + display_name),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(
        label="unknown variant owner " + display_name,
      ),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  guard declaration.variant(symbol) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(label="unknown variant " + display_name),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  let explicit_generic_arguments = if explicit_generic_arguments.is_empty() {
    []
  } else {
    check_type_arity(
      self.source.symbols,
      self.diagnostics,
      metadata.owner,
      display_name,
      explicit_generic_arguments.length(),
      loc,
    )
    check_resolved_nominal_generic_arguments(
      self.resolved_source,
      self.diagnostics,
      declaration.type_parameters,
      explicit_generic_arguments,
    )
  }
  if variant_declaration.payload.length() != arguments.length() {
    self.report_application_arity("variant arity", loc)
    return checked_expression_none_reported(
      @types.nominal_type_generic(metadata.owner, explicit_generic_arguments),
    )
  }
  let generic_arguments = if explicit_generic_arguments.is_empty() &&
    !declaration.type_parameters.is_empty() {
    guard self.infer_variant_generic_arguments(
        scope, declaration, variant_declaration, arguments, expected_result, loc,
      )
      is Some(generic_arguments) else {
      return checked_expression_none_reported(Error)
    }
    generic_arguments
  } else {
    explicit_generic_arguments
  }
  let nominal_substitution = variant_type_substitution(
    declaration.type_parameters,
    generic_arguments,
  )
  let hidden_generic_arguments = self.variant_hidden_generic_arguments(
    scope, variant_declaration, explicit_variant_generic_arguments, arguments, nominal_substitution,
    display_name, loc,
  )
  guard hidden_generic_arguments is Some(hidden_generic_arguments) else {
    return checked_expression_none_reported(Error)
  }
  let hidden_substitution = variant_generic_argument_substitution(
    variant_declaration.type_parameters,
    hidden_generic_arguments,
  )
  let checked_arguments = []
  let effects = []
  let mut complete = true
  for index in 0..<variant_declaration.payload.length() {
    let expected = variant_declaration.payload[index]
      .substitute(nominal_substitution)
      .substitute(hidden_substitution)
    let checked = self.check_checked_expr(scope, arguments[index], expected)
    match
      self.require_checked_expression(
        checked,
        arguments[index].loc(),
        "variant argument",
      ) {
      Some(argument) => checked_arguments.push(argument)
      None => complete = false
    }
    effects.push(checked.effect)
  }
  let type_ = @types.nominal_type_generic(metadata.owner, generic_arguments)
  if complete {
    checked_expression_with_effect(
      Variant(
        symbol~,
        generic_arguments=hidden_generic_arguments,
        arguments=checked_arguments,
        type_~,
        loc~,
      ),
      type_,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(type_)
  }
}

///|
fn SemanticChecker::variant_hidden_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  variant : CheckedVariantDeclaration,
  explicit : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  nominal_substitution : @types.TypeSubstitution,
  display_name : String,
  loc : SourceSpan,
) -> Array[@types.GenericArgument]? {
  if !explicit.is_empty() {
    if explicit.length() != variant.type_parameters.length() {
      self.diagnostics.push({
        kind: GenericArgumentArityMismatch(
          subject=Named(name=display_name),
          expected=variant.type_parameters.length(),
          actual=explicit.length(),
        ),
        loc,
      })
    }
    return Some(
      check_resolved_generic_arguments(
        self.resolved_source,
        self.diagnostics,
        scope,
        variant.type_parameters,
        explicit,
      ),
    )
  }
  if variant.type_parameters.is_empty() {
    return Some([])
  }
  let templates = variant.payload.map(fn(parameter) {
    parameter.substitute(nominal_substitution)
  })
  guard self.infer_variant_hidden_generic_arguments(
      scope,
      variant.type_parameters,
      templates,
      arguments,
      loc,
    )
    is Some(inferred) else {
    return None
  }
  Some(inferred.generic_arguments)
}

///|
fn SemanticChecker::infer_variant_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : CheckedEnumDeclaration,
  variant : CheckedVariantDeclaration,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> Array[@types.GenericArgument]? {
  let result_template = if expected_result is Some(_) {
    Some(
      @types.nominal_type_generic(
        declaration.symbol,
        declaration.type_parameters.map(fn(parameter) {
          parameter.generic_argument()
        }),
      ),
    )
  } else {
    None
  }
  guard self.infer_variant_owner_generic_arguments(
      scope,
      declaration.type_parameters,
      variant.payload,
      arguments,
      result_template,
      expected_result,
      loc,
    )
    is Some(inferred) else {
    return None
  }
  Some(
    declaration.type_parameters.map(fn(parameter) {
      parameter.generic_argument().substitute(inferred.substitution)
    }),
  )
}

///|
fn variant_type_substitution(
  parameters : Array[@types.TypeParameter],
  arguments : Array[@types.GenericArgument],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  let length = if parameters.length() < arguments.length() {
    parameters.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    substitution.insert_argument(parameters[index].id, arguments[index])
  }
  substitution
}

///|
fn variant_generic_argument_substitution(
  parameters : Array[@types.TypeParameter],
  arguments : Array[@types.GenericArgument],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  let length = if parameters.length() < arguments.length() {
    parameters.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    substitution.insert_argument(parameters[index].id, arguments[index])
  }
  substitution
}

///|
priv struct StructLiteralGenericEvidence {
  field_templates : Array[@types.Type]
  field_expressions : Array[@desugar.DesugaredExpr]
}

///|
fn SemanticChecker::synthesize_checked_struct_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  generic_arguments : Array[@resolve.ResolvedGenericArgument],
  fields : Array[@desugar.DesugaredStructLiteralField],
  expected : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Struct literals synthesize a nominal owner type. Value fields are checked
  // after substituting owner generic arguments and explicit existential type
  // witnesses supplied by the literal.
  guard self.type_symbol_for_name(type_name) is Some(symbol) else {
    self.diagnostics.push({ kind: UnresolvedType(type_name), loc })
    return checked_expression_none_reported(Error)
  }
  guard self.declarations.checked_struct(symbol) is Some(struct_declaration) else {
    let parameters = match self.declarations.checked_enum(symbol) {
      Some(declaration) => declaration.type_parameters
      None => []
    }
    let arguments = check_resolved_nominal_generic_arguments(
      self.resolved_source,
      self.diagnostics,
      parameters,
      generic_arguments,
    )
    let type_ = @types.nominal_type_generic(symbol, arguments)
    self.diagnostics.push({ kind: NotAStruct(type_), loc })
    return checked_expression_none_reported(Error)
  }
  let arguments = self.struct_literal_generic_arguments(
    scope,
    symbol,
    struct_declaration,
    struct_declaration.type_parameters,
    generic_arguments,
    fields,
    expected,
    loc,
  )
  check_type_arity(
    self.source.symbols,
    self.diagnostics,
    symbol,
    type_name,
    arguments.length(),
    loc,
  )
  let type_ = @types.nominal_type_generic(symbol, arguments)
  let witnesses = self.check_struct_type_witnesses(
    struct_declaration, fields, loc,
  )
  let nominal_substitution = struct_declaration.nominal_substitution(arguments)
  let existential_substitution = struct_declaration.existential_substitution(
    witnesses,
  )
  let seen = []
  let checked_fields : Array[@checked.CheckedStructLiteralField] = []
  let effects = []
  let mut complete = true
  for field in fields {
    guard field is Value(name~, value~, loc=field_loc) else { continue }
    if seen.contains(name) {
      self.diagnostics.push({ kind: DuplicateField(name~), loc: field_loc })
    } else {
      seen.push(name)
    }
    if self.source.symbols.field_named(symbol, name) is Some(field_symbol) {
      guard struct_declaration.field(field_symbol) is Some(field_declaration) else {
        self.diagnostics.push({ kind: UnknownField(name~), loc: field_loc })
        continue
      }
      let expected = field_declaration.type_
        .substitute(nominal_substitution)
        .substitute(existential_substitution)
      let checked = self.check_checked_expr(scope, value, expected)
      match
        self.require_checked_expression(checked, field_loc, "struct field") {
        Some(value) => {
          effects.push(checked.effect)
          checked_fields.push({
            symbol: field_symbol,
            name,
            value,
            loc: field_loc,
          })
        }
        None => complete = false
      }
    } else {
      self.diagnostics.push({ kind: UnknownField(name~), loc: field_loc })
    }
  }
  for field in struct_declaration.fields {
    if !seen.contains(field.name) {
      self.diagnostics.push({ kind: MissingField(name=field.name), loc })
    }
  }
  if complete {
    checked_expression_with_effect(
      StructLiteral(
        symbol~,
        generic_arguments=arguments,
        type_witnesses=witnesses,
        fields=checked_fields,
        type_~,
        loc~,
      ),
      type_,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(type_)
  }
}

///|
fn SemanticChecker::struct_literal_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  symbol : @symbol.TypeSymbolId,
  struct_declaration : CheckedStructDeclaration,
  parameters : Array[@types.TypeParameter],
  generic_arguments : Array[@resolve.ResolvedGenericArgument],
  fields : Array[@desugar.DesugaredStructLiteralField],
  expected : @types.Type?,
  loc : SourceSpan,
) -> Array[@types.GenericArgument] {
  if !generic_arguments.is_empty() {
    return check_resolved_nominal_generic_arguments(
      self.resolved_source,
      self.diagnostics,
      parameters,
      generic_arguments,
    )
  }
  if parameters.is_empty() {
    return []
  }
  let evidence = struct_literal_generic_evidence(
    self, symbol, struct_declaration, fields,
  )
  guard self.infer_struct_literal_generic_arguments(
      scope,
      parameters,
      evidence.field_templates,
      evidence.field_expressions,
      @types.nominal_type_generic(
        symbol,
        parameters.map(fn(parameter) { parameter.generic_argument() }),
      ),
      expected,
      loc,
    )
    is Some(inferred) else {
    return parameters.map(fn(_parameter) { TypeArgument(Error) })
  }
  parameters.map(fn(parameter) {
    parameter.generic_argument().substitute(inferred.substitution)
  })
}

///|
fn struct_literal_generic_evidence(
  checker : SemanticChecker,
  symbol : @symbol.TypeSymbolId,
  declaration : CheckedStructDeclaration,
  fields : Array[@desugar.DesugaredStructLiteralField],
) -> StructLiteralGenericEvidence {
  let field_templates = []
  let field_expressions = []
  for field in fields {
    guard field is Value(name~, value~, ..) else { continue }
    guard checker.source.symbols.field_named(symbol, name) is Some(field_symbol) else {
      continue
    }
    guard declaration.field(field_symbol) is Some(field_declaration) else {
      continue
    }
    field_templates.push(field_declaration.type_)
    field_expressions.push(value)
  }
  { field_templates, field_expressions }
}

///|
fn SemanticChecker::check_struct_type_witnesses(
  self : SemanticChecker,
  declaration : CheckedStructDeclaration,
  fields : Array[@desugar.DesugaredStructLiteralField],
  loc : SourceSpan,
) -> Array[@checked.CheckedStructTypeWitness] {
  let seen = []
  let witnesses : Array[@checked.CheckedStructTypeWitness] = []
  for field in fields {
    guard field is TypeWitness(name~, witness~, loc=field_loc) else { continue }
    if seen.contains(name) {
      self.diagnostics.push({ kind: DuplicateTypeMember(name~), loc: field_loc })
    } else {
      seen.push(name)
    }
    match declaration.type_member_named(name) {
      Some(type_member) =>
        witnesses.push({
          symbol: type_member.symbol,
          name,
          type_: self.check_type(witness),
          loc: field_loc,
        })
      None =>
        self.diagnostics.push({ kind: UnknownTypeMember(name~), loc: field_loc })
    }
  }
  for type_member in declaration.type_members {
    if !seen.contains(type_member.name) {
      self.diagnostics.push({
        kind: MissingTypeMember(name=type_member.name),
        loc,
      })
    }
  }
  witnesses
}
