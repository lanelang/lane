///|
priv struct PatternMatrix {
  rows : Array[Array[@checked.CheckedPattern]]
}

///|
fn PatternMatrix::PatternMatrix() -> PatternMatrix {
  { rows: [] }
}

///|
fn PatternMatrix::add(
  self : PatternMatrix,
  pattern : @checked.CheckedPattern,
) -> Unit {
  self.rows.push([pattern])
}

///|
fn SemanticChecker::check_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  // Match checking judgment:
  //
  //   Gamma |- scrutinee => S
  //   Gamma, binders(p_i : S) |- body_i <= Expected
  //   useful(p_i, previous_patterns)
  //   exhaustive(S, patterns)
  //
  // The scrutinee type is synthesized once, then every arm pattern is checked
  // against that type. Pattern binders extend only the copied arm scope. This
  // pass records the checked patterns needed by later ANF, but it does
  // not build a decision tree; the tree is an execution lowering concern.
  let scrutinee_type = self.synthesize_expr(scope, scrutinee)
  let matrix = PatternMatrix::PatternMatrix()
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      scrutinee_type,
    )
    if !matrix.is_useful(self.declarations, pattern, scrutinee_type) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    self.check_expr(arm_scope, arm.body, expected)
  }
  if !matrix.is_exhaustive(self.declarations, scrutinee_type) {
    self.diagnostics.push({ kind: NonExhaustiveMatch(scrutinee_type), loc })
  }
}

///|
fn SemanticChecker::synthesize_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  loc : SourceSpan,
) -> @types.Type {
  // Match synthesis judgment:
  //
  //   Gamma |- scrutinee => S
  //   Gamma, binders(p_i : S) |- body_i => T_i
  //   T_1 == ... == T_n
  //
  // Unlike checking mode, no result type is pushed into arm bodies. The first
  // arm establishes the synthesized result type, and later arms are required to
  // match it. Exhaustiveness and usefulness are still checked on the same
  // pattern matrix used by checking mode.
  let scrutinee_type = self.synthesize_expr(scope, scrutinee)
  let matrix = PatternMatrix::PatternMatrix()
  let mut result : @types.Type = Error
  let mut has_result = false
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      scrutinee_type,
    )
    if !matrix.is_useful(self.declarations, pattern, scrutinee_type) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    let arm_type = self.synthesize_expr(arm_scope, arm.body)
    self.check_hidden_type_escape(
      pattern.opened_type_parameters(),
      arm_type,
      arm.body.loc(),
    )
    if has_result {
      self.expect_type(result, arm_type, arm.loc)
    } else {
      result = arm_type
      has_result = true
    }
  }
  if !has_result {
    self.diagnostics.push({ kind: CannotInferExpression("empty match"), loc })
  }
  if !matrix.is_exhaustive(self.declarations, scrutinee_type) {
    self.diagnostics.push({ kind: NonExhaustiveMatch(scrutinee_type), loc })
  }
  result
}

///|
fn SemanticChecker::check_match_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  pattern : @resolve.ResolvedPattern,
  expected : @types.Type,
) -> @checked.CheckedPattern {
  // Pattern checking judgment:
  //
  //   Gamma |- p <= T ~~> checked_p, Gamma'
  //
  // Patterns are checked against an already known scrutinee type. They do not
  // synthesize the scrutinee type and do not create non-local type variables.
  // The binder set is per-pattern and rejects repeated names before the arm
  // body is checked under the extended scope.
  let binders : Array[String] = []
  self.check_pattern(scope, pattern, expected, binders)
}

///|
fn SemanticChecker::check_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  pattern : @resolve.ResolvedPattern,
  expected : @types.Type,
  binders : Array[String],
) -> @checked.CheckedPattern {
  match pattern {
    Wildcard(loc) => Wildcard(type_=expected, loc~)
    Binding(name~, symbol~, loc~) => {
      if binders.contains(name) {
        self.diagnostics.push({ kind: DuplicatePatternBinder(name~), loc })
      } else {
        binders.push(name)
      }
      scope.bind(symbol, expected)
      Binding(name~, symbol~, type_=expected, loc~)
    }
    IntLiteral(raw, loc~) => {
      self.expect_type(expected, Primitive(Int), loc)
      Literal(
        literal=Int(self.check_int_literal(raw, loc)),
        type_=expected,
        loc~,
      )
    }
    StringLiteral(value, loc~) => {
      self.expect_type(expected, Primitive(String), loc)
      Literal(literal=String(value), type_=expected, loc~)
    }
    BoolLiteral(value, loc~) => {
      self.expect_type(expected, Primitive(Bool), loc)
      Literal(literal=Bool(value), type_=expected, loc~)
    }
    QualifiedVariant(
      type_name~,
      variant~,
      type_binders~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.check_variant_pattern(
        scope, type_name, variant, type_binders, reference, arguments, expected,
        binders, loc,
      )
    Struct(type_name~, fields~, loc~) =>
      self.check_struct_pattern(
        scope, type_name, fields, expected, binders, loc,
      )
  }
}

///|
fn SemanticChecker::check_variant_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  variant : String,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@resolve.ResolvedPattern],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  match reference {
    Symbol(symbol) =>
      self.check_variant_symbol_pattern(
        scope, type_name, variant, symbol, type_binders, arguments, expected, binders,
        loc,
      )
    Ambiguous(name~, ..) => {
      self.report_ambiguous_variant_reference(name, loc)
      Wildcard(type_=Error, loc~)
    }
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          "unresolved variant " + type_name + "::" + variant,
        ),
        loc,
      })
      Wildcard(type_=Error, loc~)
    }
    UnresolvedUnqualified(name) => {
      self.diagnostics.push({
        kind: CannotInferExpression("unresolved variant " + name),
        loc,
      })
      Wildcard(type_=Error, loc~)
    }
  }
}

///|
fn SemanticChecker::check_variant_symbol_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  variant : String,
  symbol : VariantSymbolId,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  arguments : Array[@resolve.ResolvedPattern],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  // Variant pattern rule:
  //
  //   Expected = E[A_1, ..., A_n]
  //   variant v belongs to E
  //   payload_i[v][A_1, ..., A_n] checks pattern_i
  //
  // Variant patterns are nominal. The variant symbol determines the owner enum,
  // and the expected enum application supplies the type arguments used to
  // substitute payload types.
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        "unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression("unknown variant owner " + type_name),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard declaration.variant(symbol) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        "unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let type_arguments = match expected.decompose_nominal() {
    Some((owner, arguments)) if owner == metadata.owner => arguments
    _ =>
      if expected is Error {
        []
      } else {
        self.expect_type(
          expected,
          @types.nominal_type(
            metadata.owner,
            declaration.type_parameters.map(fn(parameter) {
              Parameter(parameter.id)
            }),
          ),
          loc,
        )
        []
      }
  }
  if variant_declaration.payload.length() != arguments.length() {
    self.diagnostics.push({
      kind: PatternArityMismatch(
        name=type_name + "::" + variant,
        expected=variant_declaration.payload.length(),
        actual=arguments.length(),
      ),
      loc,
    })
  }
  let substitution = variant_type_substitution(
    declaration.type_parameters,
    type_arguments,
  )
  if type_binders.length() != variant_declaration.type_parameters.length() {
    self.diagnostics.push({
      kind: TypeArgumentArityMismatch(
        name=type_name + "::" + variant,
        expected=variant_declaration.type_parameters.length(),
        actual=type_binders.length(),
      ),
      loc,
    })
  }
  let hidden_type_arguments = type_binders.map(fn(parameter) {
    @types.Type::Parameter(parameter.symbol)
  })
  let hidden_substitution = variant_type_substitution(
    variant_declaration.type_parameters,
    hidden_type_arguments,
  )
  let checked_arguments = []
  let length = if variant_declaration.payload.length() < arguments.length() {
    variant_declaration.payload.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    checked_arguments.push(
      self.check_pattern(
        scope,
        arguments[index],
        variant_declaration.payload[index]
        .substitute(substitution)
        .substitute(hidden_substitution),
        binders,
      ),
    )
  }
  Variant(
    symbol~,
    type_arguments=hidden_type_arguments,
    arguments=checked_arguments,
    type_=expected,
    loc~,
  )
}

///|
fn SemanticChecker::check_struct_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  fields : Array[@resolve.ResolvedStructPatternField],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  // Struct pattern rule:
  //
  //   Expected = S[A_1, ..., A_n]
  //   every declared field of S appears exactly once
  //   field_i[S][A_1, ..., A_n] checks pattern_i
  //
  // Source field order is ignored after checking. The checked struct pattern is
  // emitted in declaration order so ANF and later execution lowering do
  // not depend on source spelling order.
  guard self.type_symbol_for_name(type_name) is Some(symbol) else {
    self.diagnostics.push({ kind: UnresolvedType(type_name), loc })
    return Wildcard(type_=Error, loc~)
  }
  let type_arguments = match expected.decompose_nominal() {
    Some((owner, arguments)) if owner == symbol => arguments
    _ =>
      if expected is Error {
        []
      } else {
        self.expect_type(expected, @types.nominal_type(symbol, []), loc)
        []
      }
  }
  guard self.declarations.checked_struct(symbol) is Some(declaration) else {
    self.diagnostics.push({
      kind: NotAStruct(@types.nominal_type(symbol, type_arguments)),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let seen = []
  for field in fields {
    if field is Value(name~, loc~, ..) {
      if seen.contains(name) {
        self.diagnostics.push({ kind: DuplicateField(name~), loc })
      } else {
        seen.push(name)
      }
      if self.source.symbols.field_named(symbol, name) is None {
        self.diagnostics.push({ kind: UnknownField(name~), loc })
      }
    }
  }
  let substitution = declaration.nominal_substitution(type_arguments)
  let type_member_result = self.check_struct_pattern_type_binders(
    declaration, fields, loc,
  )
  let existential_substitution = declaration.pattern_existential_substitution(
    type_member_result.binders,
  )
  let checked_fields = []
  for declaration_field in declaration.fields {
    match fields.find_by_name(declaration_field.name) {
      Some(field) => {
        guard field is Value(pattern~, loc~, ..) else { continue }
        let checked = self.check_pattern(
          scope,
          pattern,
          declaration_field.type_
          .substitute(substitution)
          .substitute(existential_substitution),
          binders,
        )
        let checked_field : @checked.CheckedStructPatternField = {
          symbol: declaration_field.symbol,
          name: declaration_field.name,
          pattern: checked,
          loc,
        }
        checked_fields.push(checked_field)
      }
      None =>
        self.diagnostics.push({
          kind: MissingField(name=declaration_field.name),
          loc,
        })
    }
  }
  Struct(
    symbol~,
    type_binders=type_member_result.binders,
    fields=checked_fields,
    type_=expected,
    loc~,
  )
}

///|
priv struct CheckedStructPatternTypeBinders {
  binders : Array[@checked.CheckedStructTypeBinder]
}

///|
fn SemanticChecker::check_struct_pattern_type_binders(
  self : SemanticChecker,
  declaration : CheckedStructDeclaration,
  fields : Array[@resolve.ResolvedStructPatternField],
  loc : SourceSpan,
) -> CheckedStructPatternTypeBinders {
  let binders : Array[@checked.CheckedStructTypeBinder] = []
  let used_field_indices : Array[Int] = []
  self.check_struct_pattern_type_binder_names(declaration, fields)
  for type_member in declaration.type_members {
    let mut found = false
    for index in 0..<fields.length() {
      let field = fields[index]
      if !used_field_indices.contains(index) {
        if field is TypeBinder(name~, type_parameter~, loc=field_loc) &&
          name == type_member.name {
          used_field_indices.push(index)
          found = true
          binders.push({
            symbol: type_member.symbol,
            type_parameter: Some(
              checked_type_parameter_with_kind(type_parameter, type_member.kind),
            ),
            name: Some(name),
            loc: field_loc,
          })
        } else if field is TypeWildcard(type_parameter~, loc=field_loc) &&
          !found {
          used_field_indices.push(index)
          found = true
          binders.push({
            symbol: type_member.symbol,
            type_parameter: Some(
              checked_type_parameter_with_kind(type_parameter, type_member.kind),
            ),
            name: None,
            loc: field_loc,
          })
        }
      }
    }
    if !found {
      self.diagnostics.push({
        kind: MissingTypeMember(name=type_member.name),
        loc,
      })
    }
  }
  { binders, }
}

///|
fn SemanticChecker::check_struct_pattern_type_binder_names(
  self : SemanticChecker,
  declaration : CheckedStructDeclaration,
  fields : Array[@resolve.ResolvedStructPatternField],
) -> Unit {
  let seen = []
  for field in fields {
    if field is TypeBinder(name~, loc~, ..) {
      if seen.contains(name) {
        self.diagnostics.push({ kind: DuplicateTypeMember(name~), loc })
      } else {
        seen.push(name)
      }
      if declaration.type_member_named(name) is None {
        self.diagnostics.push({ kind: UnknownTypeMember(name~), loc })
      }
    }
  }
}

///|
fn CheckedStructDeclaration::pattern_existential_substitution(
  self : CheckedStructDeclaration,
  binders : Array[@checked.CheckedStructTypeBinder],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for binder in binders {
    if binder.type_parameter is Some(parameter) &&
      self.type_member(binder.symbol) is Some(type_member) {
      substitution.insert(
        type_member.type_parameter.id,
        Parameter(parameter.id),
      )
    }
  }
  substitution
}

///|
fn Array::find_by_name(
  self : Array[@resolve.ResolvedStructPatternField],
  name : String,
) -> @resolve.ResolvedStructPatternField? {
  for field in self {
    if field is Value(name=field_name, ..) && field_name == name {
      return Some(field)
    }
  }
  None
}

///|
fn PatternMatrix::is_useful(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  pattern : @checked.CheckedPattern,
  type_ : @types.Type,
) -> Bool {
  // Usefulness judgment:
  //
  //   useful(matrix, [p], [T])
  //
  // This is the single-scrutinee entry point into the standard pattern-matrix
  // specialization algorithm. Constructor columns are recursively expanded into
  // payload/field columns, so nested enum and struct patterns are handled by the
  // same coverage rule as top-level patterns.
  matrix_useful(declarations, self.rows, [pattern], [type_])
}

///|
fn PatternMatrix::is_exhaustive(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  type_ : @types.Type,
) -> Bool {
  // Exhaustiveness judgment:
  //
  //   !useful(matrix, [_], [T])
  //
  if type_ is Error {
    true
  } else {
    !matrix_useful(declarations, self.rows, [wildcard_pattern(type_)], [type_])
  }
}

///|
priv enum MatrixConstructor {
  BoolConstructor(Bool)
  IntConstructor(Int64)
  StringConstructor(String)
  UnitConstructor
  VariantConstructor(VariantSymbolId)
  StructConstructor(TypeSymbolId)
} derive(Eq)

///|
priv struct ConstructorSignature {
  tag : MatrixConstructor
  argument_types : Array[@types.Type]
}

///|
fn matrix_useful(
  declarations : CheckedDeclarationEnvironment,
  matrix : Array[Array[@checked.CheckedPattern]],
  vector : Array[@checked.CheckedPattern],
  types : Array[@types.Type],
) -> Bool {
  if vector.is_empty() {
    return matrix.is_empty()
  }
  guard vector.get(0) is Some(head) else { return matrix.is_empty() }
  guard types.get(0) is Some(type_) else { return matrix.is_empty() }
  let vector_tail = pattern_tail(vector)
  let type_tail = type_tail(types)
  if constructor_signature_for_pattern(head) is Some(signature) {
    return matrix_useful(
      declarations,
      specialize_matrix(matrix, signature),
      pattern_concat(constructor_arguments_for_pattern(head), vector_tail),
      type_concat(signature.argument_types, type_tail),
    )
  }
  let seen = first_column_constructor_signatures(matrix)
  if complete_constructor_signatures(declarations, type_) is Some(constructors) {
    if constructor_signatures_complete(constructors, seen) {
      return constructors.any(fn(signature) {
        matrix_useful(
          declarations,
          specialize_matrix(matrix, signature),
          pattern_concat(
            wildcard_patterns(signature.argument_types),
            vector_tail,
          ),
          type_concat(signature.argument_types, type_tail),
        )
      })
    }
  }
  matrix_useful(declarations, default_matrix(matrix), vector_tail, type_tail)
}

///|
fn specialize_matrix(
  matrix : Array[Array[@checked.CheckedPattern]],
  signature : ConstructorSignature,
) -> Array[Array[@checked.CheckedPattern]] {
  let specialized = []
  for row in matrix {
    if specialize_row(row, signature) is Some(row) {
      specialized.push(row)
    }
  }
  specialized
}

///|
fn specialize_row(
  row : Array[@checked.CheckedPattern],
  signature : ConstructorSignature,
) -> Array[@checked.CheckedPattern]? {
  guard row.get(0) is Some(head) else { return None }
  let row_tail = pattern_tail(row)
  match head {
    Wildcard(..) | Binding(..) =>
      Some(
        pattern_concat(wildcard_patterns(signature.argument_types), row_tail),
      )
    _ if constructor_signature_for_pattern(head) is Some(head_signature) &&
      head_signature.tag == signature.tag =>
      Some(pattern_concat(constructor_arguments_for_pattern(head), row_tail))
    _ => None
  }
}

///|
fn default_matrix(
  matrix : Array[Array[@checked.CheckedPattern]],
) -> Array[Array[@checked.CheckedPattern]] {
  let rows = []
  for row in matrix {
    guard row.get(0) is Some(head) else { continue }
    if head is Wildcard(..) || head is Binding(..) {
      rows.push(pattern_tail(row))
    }
  }
  rows
}

///|
fn complete_constructor_signatures(
  declarations : CheckedDeclarationEnvironment,
  type_ : @types.Type,
) -> Array[ConstructorSignature]? {
  if type_.decompose_nominal() is Some((symbol, arguments)) {
    if declarations.checked_enum(symbol) is Some(declaration) {
      return Some(
        declaration.variants.map(fn(variant) {
          {
            tag: VariantConstructor(variant.symbol),
            argument_types: variant_payload_types(
              declaration, variant, arguments,
            ),
          }
        }),
      )
    }
    if declarations.checked_struct(symbol) is Some(declaration) {
      return Some([
        {
          tag: StructConstructor(symbol),
          argument_types: struct_field_types(declaration, arguments),
        },
      ])
    }
    return None
  }
  match type_ {
    Error => Some([])
    Primitive(Bool) =>
      Some([
        { tag: BoolConstructor(false), argument_types: [] },
        { tag: BoolConstructor(true), argument_types: [] },
      ])
    Primitive(Unit) => Some([{ tag: UnitConstructor, argument_types: [] }])
    Primitive(Int) | Primitive(String) => None
    Parameter(_)
    | Constructor(_)
    | Apply(_, _)
    | TypeLambda(_, _)
    | Function(_, _)
    | Forall(_, _) => None
  }
}

///|
fn variant_payload_types(
  declaration : CheckedEnumDeclaration,
  variant : CheckedVariantDeclaration,
  arguments : Array[@types.Type],
) -> Array[@types.Type] {
  let substitution = variant_type_substitution(
    declaration.type_parameters,
    arguments,
  )
  variant.payload.map(fn(type_) { type_.substitute(substitution) })
}

///|
fn struct_field_types(
  declaration : CheckedStructDeclaration,
  arguments : Array[@types.Type],
) -> Array[@types.Type] {
  let substitution = declaration.nominal_substitution(arguments)
  declaration.fields.map(fn(field) { field.type_.substitute(substitution) })
}

///|
fn constructor_signature_for_pattern(
  pattern : @checked.CheckedPattern,
) -> ConstructorSignature? {
  match pattern {
    Wildcard(..) | Binding(..) => None
    Literal(literal~, ..) =>
      match literal {
        Bool(value) => Some({ tag: BoolConstructor(value), argument_types: [] })
        Int(value) =>
          Some({ tag: IntConstructor(value.value), argument_types: [] })
        String(value) =>
          Some({ tag: StringConstructor(value), argument_types: [] })
        Unit => Some({ tag: UnitConstructor, argument_types: [] })
      }
    Variant(symbol~, arguments~, ..) =>
      Some({
        tag: VariantConstructor(symbol),
        argument_types: arguments.map(fn(argument) { argument.type_() }),
      })
    Struct(symbol~, fields~, ..) =>
      Some({
        tag: StructConstructor(symbol),
        argument_types: fields.map(fn(field) { field.pattern.type_() }),
      })
  }
}

///|
fn constructor_arguments_for_pattern(
  pattern : @checked.CheckedPattern,
) -> Array[@checked.CheckedPattern] {
  match pattern {
    Variant(arguments~, ..) => arguments
    Struct(fields~, ..) => fields.map(fn(field) { field.pattern })
    _ => []
  }
}

///|
fn first_column_constructor_signatures(
  matrix : Array[Array[@checked.CheckedPattern]],
) -> Array[ConstructorSignature] {
  let signatures = []
  for row in matrix {
    guard row.get(0) is Some(pattern) else { continue }
    guard constructor_signature_for_pattern(pattern) is Some(signature) else {
      continue
    }
    if !constructor_signature_contains(signatures, signature.tag) {
      signatures.push(signature)
    }
  }
  signatures
}

///|
fn constructor_signatures_complete(
  complete : Array[ConstructorSignature],
  seen : Array[ConstructorSignature],
) -> Bool {
  !complete.is_empty() &&
  complete.all(fn(signature) {
    constructor_signature_contains(seen, signature.tag)
  })
}

///|
fn constructor_signature_contains(
  signatures : Array[ConstructorSignature],
  tag : MatrixConstructor,
) -> Bool {
  signatures.any(fn(signature) { signature.tag == tag })
}

///|
fn wildcard_pattern(type_ : @types.Type) -> @checked.CheckedPattern {
  Wildcard(type_~, loc=SourceSpan::dummy())
}

///|
fn wildcard_patterns(
  types : Array[@types.Type],
) -> Array[@checked.CheckedPattern] {
  types.map(wildcard_pattern)
}

///|
fn pattern_tail(
  patterns : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let tail = []
  for index in 1..<patterns.length() {
    tail.push(patterns[index])
  }
  tail
}

///|
fn type_tail(types : Array[@types.Type]) -> Array[@types.Type] {
  let tail = []
  for index in 1..<types.length() {
    tail.push(types[index])
  }
  tail
}

///|
fn pattern_concat(
  head : Array[@checked.CheckedPattern],
  tail : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn type_concat(
  head : Array[@types.Type],
  tail : Array[@types.Type],
) -> Array[@types.Type] {
  let result = head.copy()
  result.append(tail)
  result
}
