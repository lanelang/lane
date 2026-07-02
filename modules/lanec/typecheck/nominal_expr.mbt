///|

///|
fn SemanticChecker::synthesize_variant_call(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String?,
  type_arguments : Array[@resolve.ResolvedType],
  variant : String,
  variant_type_arguments : Array[@resolve.ResolvedType],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> @types.Type {
  self.synthesize_checked_variant_call(
    scope, type_name, type_arguments, variant, variant_type_arguments, reference,
    arguments, expected_result, loc,
  ).type_
}

///|
fn SemanticChecker::synthesize_checked_variant_call(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String?,
  type_arguments : Array[@resolve.ResolvedType],
  variant : String,
  variant_type_arguments : Array[@resolve.ResolvedType],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match type_name {
    Some(type_name) =>
      self.synthesize_checked_qualified_variant(
        scope, type_name, type_arguments, variant, variant_type_arguments, reference,
        arguments, expected_result, loc,
      )
    None =>
      self.synthesize_checked_unqualified_variant(
        scope, variant, reference, arguments, expected_result, loc,
      )
  }
}

///|
fn SemanticChecker::synthesize_checked_qualified_variant(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  type_arguments : Array[@resolve.ResolvedType],
  variant : String,
  variant_type_arguments : Array[@resolve.ResolvedType],
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
        type_arguments,
        variant_type_arguments,
        arguments,
        expected_result,
        loc,
      )
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="unresolved variant " + type_name + "::" + variant,
          reason=Generic,
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
        kind: CannotInferExpression(
          label="unresolved variant " + name,
          reason=Generic,
        ),
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
        [],
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
        kind: CannotInferExpression(
          label="unresolved variant " + name,
          reason=Generic,
        ),
        loc,
      })
      checked_expression_none_reported(Error)
    }
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="unresolved variant " + type_name + "::" + variant,
          reason=Generic,
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
  explicit_type_arguments : Array[@resolve.ResolvedType],
  explicit_variant_type_arguments : Array[@resolve.ResolvedType],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        label="unknown variant " + display_name,
        reason=Generic,
      ),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        label="unknown variant owner " + display_name,
        reason=Generic,
      ),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  guard declaration.variant(symbol) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        label="unknown variant " + display_name,
        reason=Generic,
      ),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  let explicit_type_arguments = if explicit_type_arguments.is_empty() {
    []
  } else {
    check_type_arity(
      self.source.symbols,
      self.diagnostics,
      metadata.owner,
      display_name,
      explicit_type_arguments.length(),
      loc,
    )
    check_resolved_type_arguments(
      self.resolved_source,
      self.diagnostics,
      declaration.type_parameters,
      explicit_type_arguments,
    )
  }
  if variant_declaration.payload.length() != arguments.length() {
    self.diagnostics.push({
      kind: CannotInferExpression(label="variant arity", reason=CallArity),
      loc,
    })
    return checked_expression_none_reported(
      @types.nominal_type(metadata.owner, explicit_type_arguments),
    )
  }
  let type_arguments = if explicit_type_arguments.is_empty() &&
    !declaration.type_parameters.is_empty() {
    guard self.infer_variant_type_arguments(
        scope, declaration, variant_declaration, arguments, expected_result, loc,
      )
      is Some(type_arguments) else {
      return checked_expression_none_reported(Error)
    }
    type_arguments
  } else {
    explicit_type_arguments
  }
  let nominal_substitution = variant_type_substitution(
    declaration.type_parameters,
    type_arguments,
  )
  let hidden_type_arguments = self.variant_hidden_type_arguments(
    scope, variant_declaration, explicit_variant_type_arguments, arguments, nominal_substitution,
    display_name, loc,
  )
  guard hidden_type_arguments is Some(hidden_type_arguments) else {
    return checked_expression_none_reported(Error)
  }
  let hidden_substitution = variant_type_substitution(
    variant_declaration.type_parameters,
    hidden_type_arguments,
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
  let type_ = @types.nominal_type(metadata.owner, type_arguments)
  if complete {
    checked_expression_with_effect(
      Variant(
        symbol~,
        type_arguments=hidden_type_arguments,
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
fn SemanticChecker::variant_hidden_type_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  variant : CheckedVariantDeclaration,
  explicit : Array[@resolve.ResolvedType],
  arguments : Array[@desugar.DesugaredExpr],
  nominal_substitution : @types.TypeSubstitution,
  display_name : String,
  loc : SourceSpan,
) -> Array[@types.Type]? {
  if !explicit.is_empty() {
    if explicit.length() != variant.type_parameters.length() {
      self.diagnostics.push({
        kind: TypeArgumentArityMismatch(
          name=display_name,
          expected=variant.type_parameters.length(),
          actual=explicit.length(),
        ),
        loc,
      })
    }
    return Some(
      check_resolved_type_arguments(
        self.resolved_source,
        self.diagnostics,
        variant.type_parameters,
        explicit,
      ),
    )
  }
  if variant.type_parameters.is_empty() {
    return Some([])
  }
  let inference = TypeArgumentInference::TypeArgumentInference(
    variant.type_parameters,
  )
  for index in 0..<variant.payload.length() {
    if self.synthesize_argument_for_type_arguments(scope, arguments[index])
      is Some(actual) {
      inference.collect(
        variant.payload[index].substitute(nominal_substitution),
        actual,
      )
    }
  }
  guard inference.type_arguments() is Some(type_arguments) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        label="hidden type arguments",
        reason=TypeArguments,
      ),
      loc,
    })
    return None
  }
  Some(type_arguments)
}

///|
fn SemanticChecker::infer_variant_type_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : CheckedEnumDeclaration,
  variant : CheckedVariantDeclaration,
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> Array[@types.Type]? {
  let inference = TypeArgumentInference::TypeArgumentInference(
    declaration.type_parameters,
  )
  if expected_result is Some(expected) {
    let result_template = @types.nominal_type(
      declaration.symbol,
      declaration.type_parameters.map(fn(parameter) { Parameter(parameter.id) }),
    )
    inference.collect(result_template, expected)
  }
  for index in 0..<variant.payload.length() {
    if self.synthesize_argument_for_type_arguments(scope, arguments[index])
      is Some(actual) {
      inference.collect(variant.payload[index], actual)
    }
  }
  guard inference.substitution() is Some(substitution) else {
    self.diagnostics.push({
      kind: CannotInferExpression(label="type arguments", reason=TypeArguments),
      loc,
    })
    return None
  }
  Some(
    declaration.type_parameters.map(fn(parameter) {
      @types.Type::Parameter(parameter.id).substitute(substitution)
    }),
  )
}

///|
fn variant_type_substitution(
  parameters : Array[@types.TypeParameter],
  arguments : Array[@types.Type],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  let length = if parameters.length() < arguments.length() {
    parameters.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    substitution.insert(parameters[index].id, arguments[index])
  }
  substitution
}

///|
fn SemanticChecker::synthesize_struct_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  type_arguments : Array[@resolve.ResolvedType],
  fields : Array[@desugar.DesugaredStructLiteralField],
  loc : SourceSpan,
) -> @types.Type {
  self.synthesize_checked_struct_literal(
    scope,
    type_name,
    type_arguments,
    fields,
    None,
    loc,
  ).type_
}

///|
fn SemanticChecker::synthesize_checked_struct_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  type_arguments : Array[@resolve.ResolvedType],
  fields : Array[@desugar.DesugaredStructLiteralField],
  expected : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.type_symbol_for_name(type_name) is Some(symbol) else {
    self.diagnostics.push({ kind: UnresolvedType(type_name), loc })
    return checked_expression_none_reported(Error)
  }
  guard self.declarations.checked_struct(symbol) is Some(struct_declaration) else {
    let parameters = match self.declarations.checked_enum(symbol) {
      Some(declaration) => declaration.type_parameters
      None => []
    }
    let arguments = check_resolved_type_arguments(
      self.resolved_source,
      self.diagnostics,
      parameters,
      type_arguments,
    )
    let type_ = @types.nominal_type(symbol, arguments)
    self.diagnostics.push({ kind: NotAStruct(type_), loc })
    return checked_expression_none_reported(Error)
  }
  let arguments = self.struct_literal_type_arguments(
    symbol,
    struct_declaration.type_parameters,
    type_arguments,
    expected,
  )
  check_type_arity(
    self.source.symbols,
    self.diagnostics,
    symbol,
    type_name,
    arguments.length(),
    loc,
  )
  let type_ = @types.nominal_type(symbol, arguments)
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
        type_arguments=arguments,
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
fn SemanticChecker::struct_literal_type_arguments(
  self : SemanticChecker,
  symbol : @symbol.TypeSymbolId,
  parameters : Array[@types.TypeParameter],
  type_arguments : Array[@resolve.ResolvedType],
  expected : @types.Type?,
) -> Array[@types.Type] {
  // Local type inference for `S::{ ... }` is intentionally one-way. If the
  // adjacent expected type is the same nominal constructor, omitted source type
  // arguments are copied from that expected type. Explicit source type
  // arguments are always respected.
  if type_arguments.is_empty() && expected is Some(expected_type) {
    match expected_type.decompose_nominal() {
      Some((expected_symbol, expected_arguments)) if expected_symbol == symbol =>
        return expected_arguments.copy()
      _ => ()
    }
  }
  check_resolved_type_arguments(
    self.resolved_source,
    self.diagnostics,
    parameters,
    type_arguments,
  )
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

///|
fn SemanticChecker::synthesize_field(
  self : SemanticChecker,
  scope : TypeScope,
  base : @desugar.DesugaredExpr,
  name : String,
  reference : @resolve.ResolvedFieldReference,
  loc : SourceSpan,
) -> @types.Type {
  let base_type = self.synthesize_expr(scope, base)
  match reference {
    Symbol(field) =>
      self.declarations.field_type(
        self.diagnostics,
        base_type,
        field,
        name,
        loc,
      )
    Unresolved(..) => {
      self.diagnostics.push({ kind: UnknownField(name~), loc })
      Error
    }
    Deferred(_) =>
      if base_type.decompose_nominal() is Some((symbol, _)) {
        guard self.source.symbols.field_named(symbol, name) is Some(field) else {
          self.diagnostics.push({ kind: UnknownField(name~), loc })
          return Error
        }
        self.declarations.field_type(
          self.diagnostics,
          base_type,
          field,
          name,
          loc,
        )
      } else if base_type is Error {
        Error
      } else {
        self.diagnostics.push({ kind: NotAStruct(base_type), loc })
        Error
      }
  }
}
