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
fn PatternMatrix::add_row(
  self : PatternMatrix,
  patterns : Array[@checked.CheckedPattern],
) -> Unit {
  self.rows.push(patterns)
}

///|
fn PatternMatrix::is_row_useful(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  patterns : Array[@checked.CheckedPattern],
  types : Array[@types.Type],
) -> Bool {
  matrix_useful(declarations, self.rows, patterns, types)
}

///|
fn PatternMatrix::is_row_exhaustive(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  types : Array[@types.Type],
) -> Bool {
  if types.any(fn(type_) { type_ is Error }) {
    true
  } else {
    !matrix_useful(declarations, self.rows, wildcard_patterns(types), types)
  }
}

///|
fn PatternMatrix::missing_witness(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  type_ : @types.Type,
) -> String? {
  if type_ is Error {
    return None
  }
  for candidate in coverage_candidates(declarations, type_, 6) {
    if matrix_useful(declarations, self.rows, [candidate.pattern], [type_]) {
      return Some(candidate.witness.to_text())
    }
  }
  None
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
priv struct RefutablePatternLetSite {
  type_ : @types.Type
  loc : SourceSpan
}

///|
fn SemanticChecker::check_irrefutable_pattern_let(
  self : SemanticChecker,
  pattern : @checked.CheckedPattern,
) -> Unit {
  if self.refutable_pattern_let_site(pattern) is Some(site) {
    self.diagnostics.push({
      kind: RefutablePatternLet(site.type_),
      loc: site.loc,
    })
  }
}

///|
fn SemanticChecker::refutable_pattern_let_site(
  self : SemanticChecker,
  pattern : @checked.CheckedPattern,
) -> RefutablePatternLetSite? {
  match pattern {
    Wildcard(..) | Binding(..) => None
    Literal(type_~, loc~, ..) => Some({ type_, loc })
    Struct(fields~, ..) => self.refutable_struct_pattern_let_site(fields)
    Variant(symbol~, arguments~, type_~, loc~, ..) =>
      if self.variant_pattern_is_irrefutable(symbol) {
        self.refutable_variant_payload_pattern_let_site(arguments)
      } else {
        Some({ type_, loc })
      }
  }
}

///|
fn SemanticChecker::refutable_struct_pattern_let_site(
  self : SemanticChecker,
  fields : Array[@checked.CheckedStructPatternField],
) -> RefutablePatternLetSite? {
  for field in fields {
    if self.refutable_pattern_let_site(field.pattern) is Some(site) {
      return Some(site)
    }
  }
  None
}

///|
fn SemanticChecker::refutable_variant_payload_pattern_let_site(
  self : SemanticChecker,
  arguments : Array[@checked.CheckedPattern],
) -> RefutablePatternLetSite? {
  for argument in arguments {
    if self.refutable_pattern_let_site(argument) is Some(site) {
      return Some(site)
    }
  }
  None
}

///|
fn SemanticChecker::variant_pattern_is_irrefutable(
  self : SemanticChecker,
  symbol : VariantSymbolId,
) -> Bool {
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    return false
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    return false
  }
  guard declaration.variants.length() == 1 else { return false }
  guard declaration.variants.get(0) is Some(variant) else { return false }
  variant.symbol == symbol
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
    DoubleLiteral(raw, loc~) => {
      self.expect_type(expected, Primitive(Double), loc)
      Literal(
        literal=Double(self.check_double_literal(raw, loc)),
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
      type_name_loc~,
      variant~,
      variant_loc~,
      type_binders~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.check_variant_pattern(
        scope, type_name, type_name_loc, variant, variant_loc, type_binders, reference,
        arguments, expected, binders, loc,
      )
    UnqualifiedVariant(variant~, variant_loc~, type_binders~, arguments~, loc~) =>
      self.check_unqualified_variant_pattern(
        scope, variant, variant_loc, type_binders, arguments, expected, binders,
        loc,
      )
    Struct(type_name~, type_name_loc~, reference~, fields~, loc~) =>
      self.check_struct_pattern(
        scope, type_name, type_name_loc, reference, fields, expected, binders, loc,
      )
  }
}

///|
fn SemanticChecker::check_variant_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  _type_name_loc : SourceSpan,
  variant : String,
  variant_loc : SourceSpan,
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
        scope, type_name, variant, variant_loc, symbol, type_binders, arguments,
        expected, binders, loc,
      )
    Ambiguous(name~, ..) => {
      self.report_ambiguous_variant_reference(name, loc)
      Wildcard(type_=Error, loc~)
    }
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(
          label="unresolved variant " + type_name + "::" + variant,
        ),
        loc,
      })
      Wildcard(type_=Error, loc~)
    }
    UnresolvedUnqualified(name) => {
      self.diagnostics.push({
        kind: VariantReferenceFailure(label="unresolved variant " + name),
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
  variant_loc : SourceSpan,
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
  // and the expected enum application supplies the generic arguments used to
  // substitute payload types.
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(
        label="unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(label="unknown variant owner " + type_name),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard declaration.variant(symbol) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(
        label="unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let generic_arguments = match expected.decompose_nominal() {
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
    generic_arguments,
  )
  if type_binders.length() != variant_declaration.type_parameters.length() {
    self.diagnostics.push({
      kind: GenericArgumentArityMismatch(
        subject=Named(name=type_name + "::" + variant),
        expected=variant_declaration.type_parameters.length(),
        actual=type_binders.length(),
      ),
      loc,
    })
  }
  let hidden_generic_arguments = type_binders.mapi(fn(index, parameter) {
    let kind = match parameter.kind {
      Some(kind) => check_resolved_kind(kind)
      None =>
        if index < variant_declaration.type_parameters.length() {
          variant_declaration.type_parameters[index].kind
        } else {
          Type
        }
    }
    match kind {
      Effect => effect_parameter_argument(parameter.symbol)
      _ => type_parameter_argument(parameter.symbol)
    }
  })
  let hidden_substitution = variant_generic_argument_substitution(
    variant_declaration.type_parameters,
    hidden_generic_arguments,
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
    variant_loc~,
    generic_arguments=hidden_generic_arguments,
    arguments=checked_arguments,
    type_=expected,
    loc~,
  )
}

///|
fn type_parameter_argument(symbol : TypeParameterId) -> @types.GenericArgument {
  TypeArgument(Parameter(symbol))
}

///|
fn effect_parameter_argument(
  symbol : TypeParameterId,
) -> @types.GenericArgument {
  EffectArgument(Parameter(symbol))
}

///|
fn SemanticChecker::check_unqualified_variant_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  variant : String,
  variant_loc : SourceSpan,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  arguments : Array[@resolve.ResolvedPattern],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  guard expected.decompose_nominal() is Some((owner, _)) else {
    if !(expected is Error) {
      self.diagnostics.push({
        kind: UnqualifiedVariantPatternNeedsExpectedEnum(variant~),
        loc,
      })
    }
    return Wildcard(type_=Error, loc~)
  }
  guard self.declarations.checked_enum(owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: UnqualifiedVariantPatternNeedsExpectedEnum(variant~),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard declaration.variant_named(variant) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: VariantReferenceFailure(label="unknown variant " + variant),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  self.check_variant_symbol_pattern(
    scope,
    "",
    variant,
    variant_loc,
    variant_declaration.symbol,
    type_binders,
    arguments,
    expected,
    binders,
    loc,
  )
}

///|
fn SemanticChecker::check_struct_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  type_name_loc : SourceSpan,
  reference : @resolve.ResolvedTypeReference,
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
  guard reference is Symbol(symbol) else {
    self.diagnostics.push({ kind: UnresolvedType(type_name), loc })
    return Wildcard(type_=Error, loc~)
  }
  let generic_arguments = match expected.decompose_nominal() {
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
      kind: NotAStruct(@types.nominal_type_generic(symbol, generic_arguments)),
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
      if declaration.field_named(name) is None {
        self.diagnostics.push({ kind: UnknownField(name~), loc })
      }
    }
  }
  let substitution = declaration.nominal_substitution(generic_arguments)
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
    type_name_loc~,
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
  DoubleConstructor(Double)
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
priv struct CoverageCandidate {
  pattern : @checked.CheckedPattern
  witness : CoverageWitness
}

///|
priv struct CoverageCandidateRow {
  patterns : Array[@checked.CheckedPattern]
  witnesses : Array[CoverageWitness]
}

///|
priv struct CoverageWitnessField {
  name : String
  value : CoverageWitness
}

///|
priv enum CoverageWitness {
  Any
  WitnessBool(Bool)
  WitnessUnit
  WitnessVariant(name~ : String, arguments~ : Array[CoverageWitness])
  WitnessStruct(name~ : String, fields~ : Array[CoverageWitnessField])
}

///|
fn coverage_candidates(
  declarations : CheckedDeclarationEnvironment,
  type_ : @types.Type,
  depth : Int,
) -> Array[CoverageCandidate] {
  if depth <= 0 {
    return [coverage_wildcard_candidate(type_)]
  }
  match type_ {
    Error => []
    Primitive(Bool) =>
      [
        {
          pattern: Literal(literal=Bool(false), type_~, loc=SourceSpan::dummy()),
          witness: WitnessBool(false),
        },
        {
          pattern: Literal(literal=Bool(true), type_~, loc=SourceSpan::dummy()),
          witness: WitnessBool(true),
        },
      ]
    Primitive(Unit) =>
      [
        {
          pattern: Literal(literal=Unit, type_~, loc=SourceSpan::dummy()),
          witness: WitnessUnit,
        },
      ]
    _ =>
      match type_.decompose_nominal() {
        Some((symbol, arguments)) =>
          nominal_coverage_candidates(
            declarations, symbol, arguments, type_, depth,
          )
        None => [coverage_wildcard_candidate(type_)]
      }
  }
}

///|
fn nominal_coverage_candidates(
  declarations : CheckedDeclarationEnvironment,
  symbol : TypeSymbolId,
  arguments : Array[@types.GenericArgument],
  type_ : @types.Type,
  depth : Int,
) -> Array[CoverageCandidate] {
  if declarations.checked_enum(symbol) is Some(declaration) {
    return enum_coverage_candidates(
      declarations, declaration, arguments, type_, depth,
    )
  }
  if declarations.checked_struct(symbol) is Some(declaration) {
    return struct_coverage_candidates(
      declarations, declaration, arguments, type_, depth,
    )
  }
  [coverage_wildcard_candidate(type_)]
}

///|
fn enum_coverage_candidates(
  declarations : CheckedDeclarationEnvironment,
  declaration : CheckedEnumDeclaration,
  arguments : Array[@types.GenericArgument],
  type_ : @types.Type,
  depth : Int,
) -> Array[CoverageCandidate] {
  let candidates = []
  for variant in declaration.variants {
    let payload_types = variant_payload_types(declaration, variant, arguments)
    for row in coverage_candidate_rows(declarations, payload_types, depth - 1) {
      candidates.push({
        pattern: Variant(
          symbol=variant.symbol,
          variant_loc=SourceSpan::dummy(),
          generic_arguments=[],
          arguments=row.patterns,
          type_~,
          loc=SourceSpan::dummy(),
        ),
        witness: WitnessVariant(name=variant.name, arguments=row.witnesses),
      })
    }
  }
  candidates
}

///|
fn struct_coverage_candidates(
  declarations : CheckedDeclarationEnvironment,
  declaration : CheckedStructDeclaration,
  arguments : Array[@types.GenericArgument],
  type_ : @types.Type,
  depth : Int,
) -> Array[CoverageCandidate] {
  let field_types = struct_field_types(declaration, arguments)
  coverage_candidate_rows(declarations, field_types, depth - 1).map(fn(row) {
    let fields : Array[@checked.CheckedStructPatternField] = []
    for index in 0..<declaration.fields.length() {
      fields.push({
        symbol: declaration.fields[index].symbol,
        name: declaration.fields[index].name,
        pattern: row.patterns[index],
        loc: SourceSpan::dummy(),
      })
    }
    let witness_fields : Array[CoverageWitnessField] = []
    for index in 0..<declaration.fields.length() {
      witness_fields.push({
        name: declaration.fields[index].name,
        value: row.witnesses[index],
      })
    }
    {
      pattern: Struct(
        symbol=declaration.symbol,
        type_name_loc=SourceSpan::dummy(),
        type_binders=[],
        fields~,
        type_~,
        loc=SourceSpan::dummy(),
      ),
      witness: WitnessStruct(name=declaration.name, fields=witness_fields),
    }
  })
}

///|
fn coverage_candidate_rows(
  declarations : CheckedDeclarationEnvironment,
  types : Array[@types.Type],
  depth : Int,
) -> Array[CoverageCandidateRow] {
  if types.is_empty() {
    return [{ patterns: [], witnesses: [] }]
  }
  let head_type = types[0]
  let tail_types = type_tail(types)
  let rows = []
  for head in coverage_candidates(declarations, head_type, depth) {
    for tail in coverage_candidate_rows(declarations, tail_types, depth) {
      let patterns = [head.pattern]
      patterns.append(tail.patterns)
      let witnesses = [head.witness]
      witnesses.append(tail.witnesses)
      rows.push({ patterns, witnesses })
    }
  }
  rows
}

///|
fn coverage_wildcard_candidate(type_ : @types.Type) -> CoverageCandidate {
  { pattern: wildcard_pattern(type_), witness: Any }
}

///|
fn CoverageWitness::to_text(self : CoverageWitness) -> String {
  match self {
    Any => "_"
    WitnessBool(value) => if value { "true" } else { "false" }
    WitnessUnit => "()"
    WitnessVariant(name~, arguments~) =>
      "\{name}(\{arguments.map(fn(argument) { argument.to_text() }).join(", ")})"
    WitnessStruct(name~, fields~) =>
      "\{name}::{ \{fields.map(fn(field) { field.to_text() }).join(", ")} }"
  }
}

///|
fn CoverageWitnessField::to_text(self : CoverageWitnessField) -> String {
  "\{self.name}: \{self.value.to_text()}"
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
    Primitive(Int) | Primitive(Double) | Primitive(String) => None
    Parameter(_)
    | Constructor(_)
    | Apply(_, _)
    | TypeLambda(_, _)
    | Function(_, _, _)
    | Forall(_, _) => None
  }
}

///|
fn variant_payload_types(
  declaration : CheckedEnumDeclaration,
  variant : CheckedVariantDeclaration,
  arguments : Array[@types.GenericArgument],
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
  arguments : Array[@types.GenericArgument],
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
        Double(value) =>
          Some({ tag: DoubleConstructor(value.value), argument_types: [] })
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
