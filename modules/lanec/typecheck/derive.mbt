///|
priv struct StructuralDeriveComponent {
  path : String
  type_ : @types.Type
  mut evidence : @checked.CheckedDeriveEvidence?
}

///|
priv struct StructuralDeriveField {
  symbol : FieldSymbolId
  name : String
  component : StructuralDeriveComponent
}

///|
priv struct StructuralDeriveVariant {
  symbol : VariantSymbolId
  name : String
  payload : Array[StructuralDeriveComponent]
}

///|
priv struct StructuralDeriveEvidenceRequirement {
  component : StructuralDeriveComponent
  required_type : @types.Type
}

///|
priv enum StructuralDeriveTarget {
  RecordTarget(
    fields~ : Array[StructuralDeriveField],
    metadata~ : @checked.CheckedDeriveMetadata
  )
  EnumerationTarget(
    variants~ : Array[StructuralDeriveVariant],
    metadata~ : @checked.CheckedDeriveMetadata
  )
}

///|
priv struct CheckedDeriveDeriverSynthesis {
  deriver : @checked.CheckedDeriveDeriver
  effect : @types.Effect
}

///|
fn SemanticChecker::synthesize_checked_derive(
  self : SemanticChecker,
  scope : TypeScope,
  capability_syntax : @resolve.ResolvedType,
  target_syntax : @resolve.ResolvedType,
  arguments : Array[@desugar.DesugaredCallArgument],
  source : @basic.DeriveSourceSite,
) -> CheckedExpressionSynthesis {
  let loc = source.loc
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
  guard self.structural_derive_target(target, loc) is Some(target_plan) else {
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  let deriver_type = @types.nominal_type_generic(abi.deriver, [
    TypeArgument(capability),
  ])
  let deriver_result = self.checked_derive_deriver(
    scope, arguments, deriver_type, loc,
  )
  let evidence_result = self.checked_derive_evidence(
    scope,
    capability,
    target_plan.components(),
    loc,
  )
  guard deriver_result is Some(deriver_synthesis) && evidence_result is Some(_) else {
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  guard target_plan.checked_shape(abi) is Some(shape) else {
    self.diagnostics.push({
      kind: InternalTypecheckFailure(
        label="complete structural derivation evidence was not attached to its component",
      ),
      loc,
    })
    return checked_expression_none_reported(
      apply_unary_type_constructor(capability, target),
    )
  }
  let result_type = apply_unary_type_constructor(capability, target)
  let metadata = target_plan.metadata()
  checked_expression_with_effect(
    Derive(
      plan={
        capability,
        target,
        abi,
        shape,
        deriver: deriver_synthesis.deriver,
        metadata,
      },
      type_=result_type,
      source~,
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
) -> CheckedDeriveDeriverSynthesis? {
  if arguments.is_empty() {
    guard self.required_contextual_offer(
        scope,
        expected,
        StructuralDeriver,
        loc,
      )
      is Some(offer) else {
      return None
    }
    let synthesis = self.check_checked_expr(scope, offer.expression, expected)
    guard self.require_checked_expression(
        synthesis, loc, "structural derivation deriver",
      )
      is Some(value) else {
      return None
    }
    return Some({
      deriver: Contextual({
        symbol: offer.symbol,
        name: offer.name,
        type_: offer.type_,
        value,
      }),
      effect: synthesis.effect,
    })
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
      Named(name~, value=argument_value, loc=argument_loc, ..) =>
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
  let synthesis = self.check_checked_expr(scope, value, expected)
  guard self.require_checked_expression(
      synthesis, loc, "structural derivation deriver",
    )
    is Some(value) else {
    return None
  }
  Some({ deriver: Explicit(value), effect: synthesis.effect })
}

///|
fn SemanticChecker::structural_derive_target(
  self : SemanticChecker,
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
        component: {
          path: declaration.name + "." + field.name,
          type_: field.type_.substitute(substitution),
          evidence: None,
        },
      }
    })
    guard self.structural_derive_metadata(symbol, declaration.name, loc)
      is Some(metadata) else {
      return None
    }
    return Some(RecordTarget(fields~, metadata~))
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
        payload: variant_payload_types(declaration, variant, arguments).mapi(fn(
          index,
          type_,
        ) {
          {
            path: declaration.name +
            "." +
            variant.name +
            "[" +
            index.to_string() +
            "]",
            type_,
            evidence: None,
          }
        }),
      }
    })
    guard self.structural_derive_metadata(symbol, declaration.name, loc)
      is Some(metadata) else {
      return None
    }
    return Some(EnumerationTarget(variants~, metadata~))
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
  abi : @checked.CheckedDeriveAbi,
) -> @checked.CheckedDeriveShape? {
  match self {
    RecordTarget(fields~, ..) => {
      let components = []
      for field in fields {
        guard field.component.evidence is Some(evidence) else { return None }
        components.push(
          (
            @checked.CheckedDeriveField::{
              symbol: field.symbol,
              name: field.name,
            },
            field.component.type_,
            evidence,
          ),
        )
      }
      Some(
        Record(
          product=@checked.CheckedDeriveProduct::make(abi.product, components),
        ),
      )
    }
    EnumerationTarget(variants~, ..) => {
      let checked_variants = []
      for variant in variants {
        let payload = []
        for component in variant.payload {
          guard component.evidence is Some(evidence) else { return None }
          payload.push(((), component.type_, evidence))
        }
        checked_variants.push(@checked.CheckedDeriveVariant::{
          symbol: variant.symbol,
          name: variant.name,
          payload: @checked.CheckedDeriveProduct::make(abi.product, payload),
        })
      }
      Some(
        Enumeration(
          sum=@checked.CheckedDeriveSum::make(
            abi.sum,
            abi.void_type,
            checked_variants,
          ),
        ),
      )
    }
  }
}

///|
fn StructuralDeriveTarget::components(
  self : StructuralDeriveTarget,
) -> Array[StructuralDeriveComponent] {
  match self {
    RecordTarget(fields~, ..) => fields.map(fn(field) { field.component })
    EnumerationTarget(variants~, ..) => {
      let components = []
      for variant in variants {
        for component in variant.payload {
          components.push(component)
        }
      }
      components
    }
  }
}

///|
fn SemanticChecker::checked_derive_evidence(
  self : SemanticChecker,
  scope : TypeScope,
  capability : @types.Type,
  components : Array[StructuralDeriveComponent],
  loc : SourceSpan,
) -> Unit? {
  let groups : Array[Array[StructuralDeriveEvidenceRequirement]] = []
  for component in components {
    let required = normalize_type_or_report(
      self.diagnostics,
      apply_unary_type_constructor(capability, component.type_),
      loc,
      context="structural derivation component evidence",
    )
    guard required is Some(required) else { return None }
    let requirement = { component, required_type: required }
    let mut group_index = -1
    for index in 0..<groups.length() {
      if groups[index][0].required_type.alpha_equal(required) {
        group_index = index
        break
      }
    }
    if group_index < 0 {
      groups.push([requirement])
    } else {
      groups[group_index].push(requirement)
    }
  }
  let mut complete = true
  for group in groups {
    let required = group[0].required_type
    let paths = group.map(fn(requirement) { requirement.component.path })
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
        for requirement in group {
          requirement.component.evidence = Some({
            path: requirement.component.path,
            required_type: required,
            selection: {
              symbol: offer.symbol,
              name: offer.name,
              type_: offer.type_,
              value,
            },
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
    Some(())
  } else {
    None
  }
}
