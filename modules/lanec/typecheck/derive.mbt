///|
priv struct StructuralDeriveComponent {
  index : Int
  path : String
  type_ : @types.Type
}

///|
priv struct StructuralDeriveField {
  symbol : FieldSymbolId
  name : String
  type_ : @types.Type
}

///|
priv struct StructuralDeriveVariant {
  symbol : VariantSymbolId
  name : String
  payload : Array[@types.Type]
}

///|
priv enum StructuralDeriveTarget {
  RecordTarget(
    declaration~ : CheckedStructDeclaration,
    fields~ : Array[StructuralDeriveField],
    representation~ : @types.Type,
    metadata~ : @checked.CheckedDeriveMetadata
  )
  EnumerationTarget(
    declaration~ : CheckedEnumDeclaration,
    variants~ : Array[StructuralDeriveVariant],
    representation~ : @types.Type,
    metadata~ : @checked.CheckedDeriveMetadata
  )
}

///|
fn SemanticChecker::synthesize_checked_derive(
  self : SemanticChecker,
  scope : TypeScope,
  capability_syntax : @resolve.ResolvedType,
  target_syntax : @resolve.ResolvedType,
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let type_checker = TypeExpressionChecker::{
    source: self.resolved_source,
    imported_environment: self.imported_environment,
    diagnostics: self.diagnostics,
    expanding: [],
    scope: scope.type_kinds,
  }
  let capability_result = type_checker.expect_kind(
    capability_syntax,
    Function([Type], Type),
  )
  let target_result = type_checker.expect_kind(target_syntax, Type)
  let capability = normalize_type_or_error(
    self.diagnostics,
    capability_result.type_,
    resolved_type_loc(capability_syntax),
    context="derive capability",
  )
  let target = normalize_type_or_error(
    self.diagnostics,
    target_result.type_,
    resolved_type_loc(target_syntax),
    context="derive target",
  )
  if capability_result.kind != Function([Type], Type) ||
    target_result.kind != Type ||
    capability.contains_error() ||
    target.contains_error() {
    return checked_expression_none_reported(Error)
  }
  guard self.structural_derive_abi(loc) is Some(abi) else {
    return checked_expression_none_reported(Error)
  }
  guard self.structural_derive_target(abi, target, loc) is Some(target_plan) else {
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  let deriver_type = @types.nominal_type_generic(abi.deriver.symbol, [
    TypeArgument(capability),
  ])
  guard self.checked_derive_deriver(scope, arguments, deriver_type, loc)
    is Some(deriver_synthesis) &&
    self.require_checked_expression(
      deriver_synthesis, loc, "structural derivation deriver",
    )
    is Some(deriver) else {
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  guard self.checked_derive_evidence(
      scope,
      capability,
      target_plan.components(),
      loc,
    )
    is Some(evidence) else {
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  let representation = target_plan.representation()
  let result_type = apply_unary_type_constructor(capability, target)
  let metadata = target_plan.metadata()
  checked_expression_with_effect(
    Derive(
      plan={
        capability,
        target,
        representation,
        abi: abi.checked(),
        shape: target_plan.checked_shape(),
        deriver,
        evidence,
        metadata,
      },
      type_=result_type,
      loc~,
    ),
    result_type,
    deriver_synthesis.effect,
  )
}

///|
fn SemanticChecker::checked_derive_deriver(
  self : SemanticChecker,
  scope : TypeScope,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  if arguments.is_empty() {
    guard self.contextual_offer_expr(scope, expected, loc) is Some(expression) else {
      return None
    }
    return Some(self.check_checked_expr(scope, expression, expected))
  }
  let mut value : @desugar.DesugaredExpr? = None
  let mut valid = true
  for argument in arguments {
    match argument {
      Positional(loc=argument_loc, ..) => {
        self.diagnostics.push({
          kind: AutoArgumentMustBeNamed,
          loc: argument_loc,
        })
        valid = false
      }
      Named(name~, value=argument_value, loc=argument_loc) =>
        if name != "deriver" {
          self.diagnostics.push({
            kind: UnknownContextualArgument(name~),
            loc: argument_loc,
          })
          valid = false
        } else if value is Some(_) {
          self.diagnostics.push({
            kind: DuplicateNamedArgument(name~),
            loc: argument_loc,
          })
          valid = false
        } else {
          value = Some(argument_value)
        }
    }
  }
  if !valid {
    return None
  }
  guard value is Some(value) else {
    self.diagnostics.push({ kind: CallArityMismatch(expected=1, actual=0), loc })
    return None
  }
  Some(self.check_checked_expr(scope, value, expected))
}

///|
fn SemanticChecker::structural_derive_target(
  self : SemanticChecker,
  abi : StructuralDeriveAbi,
  target : @types.Type,
  loc : SourceSpan,
) -> StructuralDeriveTarget? {
  let decomposition = target.decompose_nominal() catch {
    error => {
      report_type_computation_failure(
        self.diagnostics,
        "structural derivation target",
        loc,
        error,
      )
      return None
    }
  }
  guard decomposition is Some((symbol, arguments)) else {
    self.report_unrepresentable_derive_target(
      target, "the normalized target is not a nominal struct or enum", loc,
    )
    return None
  }
  if self.declarations.checked_struct(symbol) is Some(declaration) {
    if !declaration.type_members.is_empty() {
      self.report_unrepresentable_derive_target(
        target, "the target declares hidden existential type members", loc,
      )
      return None
    }
    let substitution = declaration.nominal_substitution(arguments)
    let fields = declaration.fields.map(fn(field) {
      StructuralDeriveField::{
        symbol: field.symbol,
        name: field.name,
        type_: field.type_.substitute(substitution),
      }
    })
    guard self.structural_derive_metadata(symbol, declaration.name, loc)
      is Some(metadata) else {
      return None
    }
    return Some(
      RecordTarget(
        declaration~,
        fields~,
        representation=product_representation_type(
          abi,
          fields.map(fn(field) { field.type_ }),
        ),
        metadata~,
      ),
    )
  }
  if self.declarations.checked_enum(symbol) is Some(declaration) {
    if declaration.variants.any(fn(variant) {
        !variant.type_parameters.is_empty()
      }) {
      self.report_unrepresentable_derive_target(
        target, "the target contains a variant with hidden existential type parameters",
        loc,
      )
      return None
    }
    let variants = declaration.variants.map(fn(variant) {
      StructuralDeriveVariant::{
        symbol: variant.symbol,
        name: variant.name,
        payload: variant_payload_types(declaration, variant, arguments),
      }
    })
    guard self.structural_derive_metadata(symbol, declaration.name, loc)
      is Some(metadata) else {
      return None
    }
    return Some(
      EnumerationTarget(
        declaration~,
        variants~,
        representation=sum_representation_type(abi, variants),
        metadata~,
      ),
    )
  }
  self.report_unrepresentable_derive_target(
    target, "the normalized nominal declaration is neither a struct nor an enum",
    loc,
  )
  None
}

///|
fn SemanticChecker::report_unrepresentable_derive_target(
  self : SemanticChecker,
  target : @types.Type,
  reason : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({
    kind: UnrepresentableStructuralDerivationTarget(target~, reason~),
    loc,
  })
}

///|
fn SemanticChecker::structural_derive_metadata(
  self : SemanticChecker,
  symbol : TypeSymbolId,
  name : String,
  loc : SourceSpan,
) -> @checked.CheckedDeriveMetadata? {
  guard self.nominal_module_path(symbol) is Some(module_path) else {
    self.diagnostics.push({
      kind: InternalTypecheckFailure(
        label="missing module ownership for structural derivation target",
      ),
      loc,
    })
    return None
  }
  Some({ name, qualified_name: module_path + "." + name })
}

///|
fn SemanticChecker::nominal_module_path(
  self : SemanticChecker,
  symbol : TypeSymbolId,
) -> String? {
  for declaration in self.resolved_source.declarations {
    match declaration {
      Struct(declaration) if declaration.symbol == symbol =>
        return Some(self.resolved_source.module_path.components.join("."))
      Enum(declaration) if declaration.symbol == symbol =>
        return Some(self.resolved_source.module_path.components.join("."))
      ExternalType(declaration) if declaration.symbol == symbol =>
        return Some(self.resolved_source.module_path.components.join("."))
      _ => ()
    }
  }
  for module_ in self.imported_environment.modules {
    for reference in module_.type_references {
      if reference.symbol == symbol {
        return Some(reference.module_path)
      }
    }
    for type_ in module_.types {
      match type_ {
        Struct(declaration) if declaration.symbol == symbol =>
          return Some(module_.module_path)
        Enum(declaration) if declaration.symbol == symbol =>
          return Some(module_.module_path)
        External(declaration) if declaration.symbol == symbol =>
          return Some(module_.module_path)
        _ => ()
      }
    }
  }
  None
}

///|
fn StructuralDeriveTarget::representation(
  self : StructuralDeriveTarget,
) -> @types.Type {
  match self {
    RecordTarget(representation~, ..)
    | EnumerationTarget(representation~, ..) => representation
  }
}

///|
fn StructuralDeriveTarget::metadata(
  self : StructuralDeriveTarget,
) -> @checked.CheckedDeriveMetadata {
  match self {
    RecordTarget(metadata~, ..) | EnumerationTarget(metadata~, ..) => metadata
  }
}

///|
fn StructuralDeriveTarget::checked_shape(
  self : StructuralDeriveTarget,
) -> @checked.CheckedDeriveShape {
  match self {
    RecordTarget(fields~, ..) =>
      Record(
        fields=fields.map(fn(field) {
          { symbol: field.symbol, name: field.name, type_: field.type_ }
        }),
      )
    EnumerationTarget(variants~, ..) =>
      Enumeration(
        variants=variants.map(fn(variant) {
          {
            symbol: variant.symbol,
            name: variant.name,
            payload: variant.payload,
          }
        }),
      )
  }
}

///|
fn StructuralDeriveTarget::components(
  self : StructuralDeriveTarget,
) -> Array[StructuralDeriveComponent] {
  match self {
    RecordTarget(declaration~, fields~, ..) =>
      fields.mapi(fn(index, field) {
        { index, path: declaration.name + "." + field.name, type_: field.type_ }
      })
    EnumerationTarget(declaration~, variants~, ..) => {
      let components = []
      for variant in variants {
        for index in 0..<variant.payload.length() {
          components.push({
            index: components.length(),
            path: declaration.name +
            "." +
            variant.name +
            "[" +
            index.to_string() +
            "]",
            type_: variant.payload[index],
          })
        }
      }
      components
    }
  }
}

///|
fn product_representation_type(
  abi : StructuralDeriveAbi,
  components : Array[@types.Type],
) -> @types.Type {
  product_suffix_types(abi, components)[0]
}

///|
fn product_suffix_types(
  abi : StructuralDeriveAbi,
  components : Array[@types.Type],
) -> Array[@types.Type] {
  let suffixes = Array::make(
    components.length() + 1,
    @types.Type::Primitive(Unit),
  )
  for index = components.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = @types.nominal_type(abi.product.symbol, [
      components[index],
      suffixes[index + 1],
    ])
  }
  suffixes
}

///|
fn sum_representation_type(
  abi : StructuralDeriveAbi,
  variants : Array[StructuralDeriveVariant],
) -> @types.Type {
  sum_suffix_types(abi, variants)[0]
}

///|
fn sum_suffix_types(
  abi : StructuralDeriveAbi,
  variants : Array[StructuralDeriveVariant],
) -> Array[@types.Type] {
  let suffixes = Array::make(
    variants.length() + 1,
    @types.Type::Constructor(abi.void_declaration.symbol),
  )
  for index = variants.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = @types.nominal_type(abi.sum.symbol, [
      product_representation_type(abi, variants[index].payload),
      suffixes[index + 1],
    ])
  }
  suffixes
}

///|
fn SemanticChecker::checked_derive_evidence(
  self : SemanticChecker,
  scope : TypeScope,
  capability : @types.Type,
  components : Array[StructuralDeriveComponent],
  loc : SourceSpan,
) -> Array[@checked.CheckedDeriveEvidence]? {
  let groups : Array[Array[StructuralDeriveComponent]] = []
  for component in components {
    let required = normalize_type_or_report(
      self.diagnostics,
      apply_unary_type_constructor(capability, component.type_),
      loc,
      context="structural derivation component evidence",
    )
    guard required is Some(required) else { return None }
    let normalized = { ..component, type_: required }
    let mut group_index = -1
    for index in 0..<groups.length() {
      if groups[index][0].type_.alpha_equal(required) {
        group_index = index
        break
      }
    }
    if group_index < 0 {
      groups.push([normalized])
    } else {
      groups[group_index].push(normalized)
    }
  }
  let evidence_slots : Array[@checked.CheckedDeriveEvidence?] = Array::make(
    components.length(),
    None,
  )
  let mut complete = true
  for group in groups {
    let required = group[0].type_
    let paths = group.map(fn(component) { component.path })
    match self.lookup_contextual_offer(scope, required, loc) {
      ContextualOfferFound(offer) => {
        let checked = self.check_checked_expr(scope, offer.expression, required)
        guard self.require_checked_expression(
            checked, loc, "structural derivation component evidence",
          )
          is Some(value) else {
          complete = false
          continue
        }
        for component in group {
          evidence_slots[component.index] = Some({
            path: component.path,
            required_type: required,
            value,
          })
        }
      }
      ContextualOfferMissing => {
        self.diagnostics.push({
          kind: MissingDeriveEvidence(required~, paths~),
          loc,
        })
        complete = false
      }
      ContextualOfferAmbiguous(candidates) => {
        self.diagnostics.push({
          kind: AmbiguousDeriveEvidence(
            required~,
            paths~,
            candidates=candidates.map(fn(candidate) {
              contextual_offer_diagnostic_candidate(candidate)
            }),
          ),
          loc,
        })
        complete = false
      }
      ContextualOfferComputationFailed => complete = false
    }
  }
  if complete {
    let evidence = []
    for slot in evidence_slots {
      guard slot is Some(value) else {
        abort("complete structural derivation evidence is missing")
      }
      evidence.push(value)
    }
    Some(evidence)
  } else {
    None
  }
}
