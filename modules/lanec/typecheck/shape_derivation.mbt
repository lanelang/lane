///|
fn SemanticChecker::synthesize_checked_compile_time_call(
  self : SemanticChecker,
  scope : TypeScope,
  intrinsic : @abi.CompileTimeIntrinsic,
  callee_type : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.instantiate_compile_time_callable(
      scope, intrinsic, callee_type, arguments, expected_result, loc,
    )
    is Some(instantiated) else {
    return checked_expression_none_reported(Error)
  }
  guard self.check_checked_call_arguments(
      scope,
      instantiated.parameters,
      arguments,
      loc,
    )
    is Some(checked_arguments) else {
    return checked_expression_none_reported(instantiated.result)
  }
  match intrinsic {
    Shape =>
      self.checked_shape_witness_call(instantiated, checked_arguments, loc)
    ShapeFold =>
      self.checked_shape_fold_call(scope, instantiated, checked_arguments, loc)
  }
}

///|
fn SemanticChecker::instantiate_compile_time_callable(
  self : SemanticChecker,
  scope : TypeScope,
  intrinsic : @abi.CompileTimeIntrinsic,
  callee_type : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> InstantiatedCallableType? {
  match callee_type {
    Function(parameters, result, effect) =>
      if self.check_application_arity(
          parameters.length(),
          arguments.length(),
          loc,
          true,
        ) {
        Some({ generic_arguments: [], parameters, result, effect })
      } else {
        None
      }
    Forall(type_parameters, body) =>
      self.instantiate_generic_callable(
        scope,
        type_parameters,
        body,
        arguments,
        expected_result,
        intrinsic.name(),
        loc,
        true,
      )
    _ => {
      self.diagnostics.push({
        kind: InvalidCompileTimeBuiltinSignature(
          name=intrinsic.name(),
          callee_type,
        ),
        loc,
      })
      None
    }
  }
}

///|
fn SemanticChecker::checked_shape_witness_call(
  self : SemanticChecker,
  instantiated : InstantiatedCallableType,
  checked_arguments : CheckedCallArguments,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  if !instantiated.parameters.is_empty() ||
    instantiated.effect.canonicalize() != Empty {
    self.diagnostics.push({
      kind: InvalidCompileTimeBuiltinSignature(
        name=@abi.CompileTimeIntrinsic::Shape.name(),
        Function(
          instantiated.parameters,
          instantiated.result,
          instantiated.effect,
        ),
      ),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  guard shape_witness_represented_type(
      instantiated.result,
      self.diagnostics,
      loc,
    )
    is Some(represented) else {
    self.diagnostics.push({
      kind: InvalidShapeWitnessType(instantiated.result),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  checked_expression_with_effect(
    ShapeWitness(represented~, type_=instantiated.result, loc~),
    instantiated.result,
    checked_arguments.effect,
  )
}

///|
fn SemanticChecker::checked_shape_fold_call(
  self : SemanticChecker,
  scope : TypeScope,
  instantiated : InstantiatedCallableType,
  checked_arguments : CheckedCallArguments,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard instantiated.parameters is [_, _] &&
    checked_arguments.arguments
    is [{ value: ShapeWitness(represented~, ..), .. }, { value: algebra, .. }] &&
    instantiated.effect.canonicalize() == Empty else {
    self.report_invalid_shape_fold_signature(instantiated, loc)
    return checked_expression_none_reported(Error)
  }
  guard shape_fold_result_constructor(
      instantiated.result,
      represented,
      self.diagnostics,
      loc,
    )
    is Some(result_constructor) else {
    self.report_invalid_shape_fold_signature(instantiated, loc)
    return checked_expression_none_reported(Error)
  }
  let algebra_type = algebra.type_()
  let algebra_symbol = self.resolved_source.symbols.define_value(
    "$shape_algebra",
    LocalBinding,
    loc,
  )
  let fold_scope = scope.copy()
  fold_scope.bind(algebra_symbol, "$shape_algebra", algebra_type)
  let algebra_value = checked_expression(
    Value(
      name="$shape_algebra",
      symbol=algebra_symbol,
      type_=algebra_type,
      loc~,
    ),
    algebra_type,
  )
  guard self.fold_shape_target(
      fold_scope,
      algebra_value,
      result_constructor,
      represented,
      instantiated.result,
      loc,
    )
    is Some(folded) &&
    self.require_checked_expression(folded, loc, "Shape fold expansion")
    is Some(result) else {
    return checked_expression_none_reported(Error)
  }
  let declaration : @checked.CheckedLetDeclaration = {
    is_public: false,
    is_offered: false,
    symbol: algebra_symbol,
    name: "$shape_algebra",
    name_loc: loc,
    initializer: algebra,
    type_: algebra_type,
    loc,
  }
  let items : Array[@checked.CheckedLocalItem] = [Let(declaration)]
  checked_expression_with_effect(
    Block(items~, result~, type_=instantiated.result, loc~),
    instantiated.result,
    effect_union([checked_arguments.effect, folded.effect]),
  )
}

///|
priv struct ShapeProductRepresentation {
  pair_types : Array[@types.Type]
  type_ : @types.Type
}

///|
priv struct FoldedShapeProduct {
  evidence : CheckedExpressionSynthesis
  representation : ShapeProductRepresentation
}

///|
priv struct ShapeVariantRepresentation {
  declaration : CheckedVariantDeclaration
  payload_types : Array[@types.Type]
  product : ShapeProductRepresentation
}

///|
priv struct ShapeSumRepresentation {
  variants : Array[ShapeVariantRepresentation]
  sum_types : Array[@types.Type]
  type_ : @types.Type
}

///|
priv struct FoldedShapeSum {
  evidence : CheckedExpressionSynthesis
  representation : ShapeSumRepresentation
}

///|
fn SemanticChecker::report_invalid_shape_fold_signature(
  self : SemanticChecker,
  instantiated : InstantiatedCallableType,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({
    kind: InvalidCompileTimeBuiltinSignature(
      name=@abi.CompileTimeIntrinsic::ShapeFold.name(),
      Function(
        instantiated.parameters,
        instantiated.result,
        instantiated.effect,
      ),
    ),
    loc,
  })
}

///|
fn shape_fold_result_constructor(
  result : @types.Type,
  represented : @types.Type,
  diagnostics : Array[TypeCheckDiagnostic],
  loc : SourceSpan,
) -> @types.Type? {
  guard normalize_type_or_report(
      diagnostics,
      result,
      loc,
      context="Shape fold result",
    )
    is Some(result) &&
    result is Apply(result_callee, [TypeArgument(argument)]) &&
    normalize_type_or_report(
      diagnostics,
      represented,
      loc,
      context="Shape witness target",
    )
    is Some(represented) &&
    argument.alpha_equal(represented) else {
    return None
  }
  Some(result_callee)
}

///|
fn shape_fold_component_type(
  result_constructor : @types.Type,
  component : @types.Type,
) -> @types.Type {
  Apply(result_constructor, [TypeArgument(component)])
}

///|
fn SemanticChecker::fold_shape_target(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  target : @types.Type,
  result_type : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  match
    decompose_nominal_or_report(
      self.diagnostics,
      target,
      loc,
      context="Shape target",
    ) {
    Nominal(symbol, arguments) =>
      match self.declarations.checked_struct(symbol) {
        Some(declaration) =>
          self.fold_shape_struct(
            scope, algebra, result_constructor, target, result_type, declaration,
            arguments, loc,
          )
        None =>
          match self.declarations.checked_enum(symbol) {
            Some(declaration) =>
              self.fold_shape_enum(
                scope, algebra, result_constructor, target, result_type, declaration,
                arguments, loc,
              )
            None => self.fold_atomic_shape(scope, target, result_type, loc)
          }
      }
    NotNominal => self.fold_atomic_shape(scope, target, result_type, loc)
    ComputationFailed => None
  }
}

///|
fn SemanticChecker::fold_shape_enum(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  target : @types.Type,
  result_type : @types.Type,
  declaration : CheckedEnumDeclaration,
  generic_arguments : Array[@types.GenericArgument],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  if declaration.variants.is_empty() {
    self.diagnostics.push({
      kind: UnsupportedShapeTarget(target, EmptyEnum),
      loc,
    })
    return None
  }
  if declaration.variants.any(fn(variant) {
      !variant.type_parameters.is_empty()
    }) {
    self.diagnostics.push({
      kind: UnsupportedShapeTarget(target, VariantTypeParameters),
      loc,
    })
    return None
  }
  let substitution = variant_type_substitution(
    declaration.type_parameters,
    generic_arguments,
  )
  let payload_types = declaration.variants.map(fn(variant) {
    variant.payload.map(fn(payload) { payload.substitute(substitution) })
  })
  let components = []
  for payload in payload_types {
    components.append(payload)
  }
  guard self.shape_has_direct_recursion(components, target, loc)
    is Some(recursive) else {
    return None
  }
  if recursive {
    let self_symbol = self.resolved_source.symbols.define_value(
      "$shape_self",
      Parameter,
      loc,
    )
    let self_evidence = checked_expression(
      Value(name="$shape_self", symbol=self_symbol, type_=result_type, loc~),
      result_type,
    )
    guard self.build_enum_shape_body(
        scope,
        algebra,
        result_constructor,
        target,
        result_type,
        declaration,
        payload_types,
        Some(self_evidence),
        loc,
      )
      is Some(body) &&
      self.require_checked_expression(body, loc, "recursive enum Shape body")
      is Some(body_expression) else {
      return None
    }
    let builder = checked_function_literal(
      self_symbol, "$shape_self", result_type, result_type, body_expression, loc,
    )
    Some(
      self.apply_shape_algebra_operation(
        scope,
        algebra,
        "fix",
        [builder],
        Some(result_type),
        loc,
      ),
    )
  } else {
    self.build_enum_shape_body(
      scope,
      algebra,
      result_constructor,
      target,
      result_type,
      declaration,
      payload_types,
      None,
      loc,
    )
  }
}

///|
fn SemanticChecker::build_enum_shape_body(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  target : @types.Type,
  result_type : @types.Type,
  declaration : CheckedEnumDeclaration,
  payload_types : Array[Array[@types.Type]],
  self_evidence : CheckedExpressionSynthesis?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  let variant_products = []
  let variant_evidence = []
  for variant_index in 0..<declaration.variants.length() {
    let components = []
    for component in payload_types[variant_index] {
      guard self.shape_component_evidence(
          scope, result_constructor, target, component, self_evidence, loc,
        )
        is Some(evidence) else {
        return None
      }
      components.push(evidence)
    }
    guard self.fold_shape_product(
        scope, algebra, result_constructor, components, loc,
      )
      is Some(product) else {
      return None
    }
    variant_products.push({
      declaration: declaration.variants[variant_index],
      payload_types: payload_types[variant_index],
      product: product.representation,
    })
    variant_evidence.push(
      self.apply_shape_algebra_operation(
        scope,
        algebra,
        "variant",
        [
          checked_string_literal(declaration.variants[variant_index].name, loc),
          product.evidence,
        ],
        Some(
          shape_fold_component_type(
            result_constructor,
            product.representation.type_,
          ),
        ),
        loc,
      ),
    )
  }
  guard self.fold_shape_sum(
      scope, algebra, result_constructor, variant_products, variant_evidence, loc,
    )
    is Some(sum) else {
    return None
  }
  let to = self.checked_enum_to_representation(
    target,
    declaration,
    sum.representation,
    loc,
  )
  let from = self.checked_enum_from_representation(
    target,
    declaration,
    sum.representation,
    loc,
  )
  Some(
    self.apply_shape_algebra_operation(
      scope,
      algebra,
      "iso",
      [checked_string_literal(declaration.name, loc), to, from, sum.evidence],
      Some(result_type),
      loc,
    ),
  )
}

///|
fn SemanticChecker::fold_shape_sum(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  variants : Array[ShapeVariantRepresentation],
  evidence : Array[CheckedExpressionSynthesis],
  loc : SourceSpan,
) -> FoldedShapeSum? {
  guard !evidence.is_empty() else { return None }
  let mut combined = evidence[evidence.length() - 1]
  let mut representation_type = variants[variants.length() - 1].product.type_
  let sum_types_reversed = []
  for index = evidence.length() - 2; index >= 0; index = index - 1 {
    combined = self.apply_shape_algebra_operation(
      scope,
      algebra,
      "sum",
      [evidence[index], combined],
      None,
      loc,
    )
    guard shape_fold_result_argument(
        combined.type_,
        result_constructor,
        self.diagnostics,
        loc,
      )
      is Some(sum_type) else {
      return None
    }
    sum_types_reversed.push(sum_type)
    representation_type = sum_type
  }
  Some({
    evidence: combined,
    representation: {
      variants,
      sum_types: sum_types_reversed.rev(),
      type_: representation_type,
    },
  })
}

///|
fn SemanticChecker::fold_atomic_shape(
  self : SemanticChecker,
  scope : TypeScope,
  _target : @types.Type,
  result_type : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  Some(self.checked_contextual_requirement(scope, result_type, loc))
}

///|
fn SemanticChecker::checked_contextual_requirement(
  self : SemanticChecker,
  scope : TypeScope,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Shape expansion introduces an ordinary local function with an omitted
  // contextual parameter. The existing direct-call checker owns lookup,
  // provider composition, ambiguity, shadowing, and cycle handling.
  let function_symbol = self.resolved_source.symbols.define_value(
    "$shape_requirement",
    LocalFunction,
    loc,
  )
  let parameter_symbol = self.resolved_source.symbols.define_value(
    "$shape_evidence",
    Parameter,
    loc,
  )
  let parameter : @checked.CheckedValueParameter = {
    symbol: parameter_symbol,
    is_auto: true,
    is_offered: false,
    name: "$shape_evidence",
    name_loc: loc,
    type_: expected,
    loc,
  }
  let function_type = @types.Type::Function([expected], expected, Empty)
  scope.bind_function(function_symbol, "$shape_requirement", function_type, [
    parameter,
  ])
  let checked = self.check_checked_expr(
    scope,
    Call(
      callee=Var(
        name="$shape_requirement",
        reference=Symbol(function_symbol),
        loc~,
      ),
      arguments=[],
      loc~,
    ),
    expected,
  )
  guard checked.expression
    is Some(Call(arguments=[{ value: evidence, .. }], ..)) else {
    return checked
  }
  checked_expression_with_effect(evidence, expected, checked.effect)
}

///|
fn SemanticChecker::fold_shape_struct(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  target : @types.Type,
  result_type : @types.Type,
  declaration : CheckedStructDeclaration,
  generic_arguments : Array[@types.GenericArgument],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  if !declaration.type_members.is_empty() {
    self.diagnostics.push({
      kind: UnsupportedShapeTarget(target, StructTypeMembers),
      loc,
    })
    return None
  }
  let substitution = declaration.nominal_substitution(generic_arguments)
  let component_types = declaration.fields.map(fn(field) {
    field.type_.substitute(substitution)
  })
  guard self.shape_has_direct_recursion(component_types, target, loc)
    is Some(recursive) else {
    return None
  }
  if recursive {
    let self_symbol = self.resolved_source.symbols.define_value(
      "$shape_self",
      Parameter,
      loc,
    )
    let self_evidence = checked_expression(
      Value(name="$shape_self", symbol=self_symbol, type_=result_type, loc~),
      result_type,
    )
    guard self.build_struct_shape_body(
        scope,
        algebra,
        result_constructor,
        target,
        result_type,
        declaration,
        component_types,
        Some(self_evidence),
        loc,
      )
      is Some(body) &&
      self.require_checked_expression(body, loc, "recursive Shape body")
      is Some(body_expression) else {
      return None
    }
    let builder = checked_function_literal(
      self_symbol, "$shape_self", result_type, result_type, body_expression, loc,
    )
    Some(
      self.apply_shape_algebra_operation(
        scope,
        algebra,
        "fix",
        [builder],
        Some(result_type),
        loc,
      ),
    )
  } else {
    self.build_struct_shape_body(
      scope,
      algebra,
      result_constructor,
      target,
      result_type,
      declaration,
      component_types,
      None,
      loc,
    )
  }
}

///|
fn SemanticChecker::build_struct_shape_body(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  target : @types.Type,
  result_type : @types.Type,
  declaration : CheckedStructDeclaration,
  component_types : Array[@types.Type],
  self_evidence : CheckedExpressionSynthesis?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  let components = []
  for index in 0..<component_types.length() {
    guard self.shape_component_evidence(
        scope,
        result_constructor,
        target,
        component_types[index],
        self_evidence,
        loc,
      )
      is Some(component) else {
      return None
    }
    let label = checked_string_literal(declaration.fields[index].name, loc)
    components.push(
      self.apply_shape_algebra_operation(
        scope,
        algebra,
        "field",
        [label, component],
        Some(
          shape_fold_component_type(result_constructor, component_types[index]),
        ),
        loc,
      ),
    )
  }
  guard self.fold_shape_product(
      scope, algebra, result_constructor, components, loc,
    )
    is Some(product) else {
    return None
  }
  let to = self.checked_struct_to_representation(
    target,
    declaration,
    product.representation,
    loc,
  )
  let from = self.checked_struct_from_representation(
    target,
    declaration,
    product.representation,
    loc,
  )
  let label = checked_string_literal(declaration.name, loc)
  Some(
    self.apply_shape_algebra_operation(
      scope,
      algebra,
      "iso",
      [label, to, from, product.evidence],
      Some(result_type),
      loc,
    ),
  )
}

///|
fn SemanticChecker::shape_component_evidence(
  self : SemanticChecker,
  scope : TypeScope,
  result_constructor : @types.Type,
  target : @types.Type,
  component : @types.Type,
  self_evidence : CheckedExpressionSynthesis?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis? {
  guard self.shape_has_direct_recursion([component], target, loc)
    is Some(recursive) else {
    return None
  }
  if recursive {
    return self_evidence
  }
  let expected = shape_fold_component_type(result_constructor, component)
  Some(self.checked_contextual_requirement(scope, expected, loc))
}

///|
fn SemanticChecker::shape_has_direct_recursion(
  self : SemanticChecker,
  components : Array[@types.Type],
  target : @types.Type,
  loc : SourceSpan,
) -> Bool? {
  for component in components {
    let recursive = component.equals(target) catch {
      error => {
        report_type_computation_failure(
          self.diagnostics,
          "Shape component",
          loc,
          error,
        )
        return None
      }
    }
    if recursive {
      return Some(true)
    }
  }
  Some(false)
}

///|
fn SemanticChecker::fold_shape_product(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  result_constructor : @types.Type,
  components : Array[CheckedExpressionSynthesis],
  loc : SourceSpan,
) -> FoldedShapeProduct? {
  let mut evidence = self.checked_shape_algebra_field(algebra, "unit", loc)
  let mut representation_type : @types.Type = Primitive(Unit)
  let pair_types_reversed = []
  for index = components.length() - 1; index >= 0; index = index - 1 {
    evidence = self.apply_shape_algebra_operation(
      scope,
      algebra,
      "product",
      [components[index], evidence],
      None,
      loc,
    )
    guard shape_fold_result_argument(
        evidence.type_,
        result_constructor,
        self.diagnostics,
        loc,
      )
      is Some(pair_type) else {
      return None
    }
    pair_types_reversed.push(pair_type)
    representation_type = pair_type
  }
  Some({
    evidence,
    representation: {
      pair_types: pair_types_reversed.rev(),
      type_: representation_type,
    },
  })
}

///|
fn shape_fold_result_argument(
  type_ : @types.Type,
  result_callee : @types.Type,
  diagnostics : Array[TypeCheckDiagnostic],
  loc : SourceSpan,
) -> @types.Type? {
  guard normalize_type_or_report(
      diagnostics,
      type_,
      loc,
      context="Shape algebra result",
    )
    is Some(type_) &&
    type_ is Apply(actual_constructor, [TypeArgument(argument)]) &&
    actual_constructor.alpha_equal(result_callee) else {
    return None
  }
  Some(argument)
}

///|
fn SemanticChecker::checked_shape_algebra_field(
  self : SemanticChecker,
  algebra : CheckedExpressionSynthesis,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.require_checked_expression(algebra, loc, "Shape algebra")
    is Some(base) else {
    return checked_expression_none_reported(Error)
  }
  guard decompose_nominal_or_report(
      self.diagnostics,
      algebra.type_,
      loc,
      context="Shape algebra",
    )
    is Nominal(symbol, _) &&
    self.declarations.checked_struct(symbol) is Some(declaration) &&
    declaration.field_named(name) is Some(field) else {
    self.diagnostics.push({ kind: UnknownField(name~), loc })
    return checked_expression_none_reported(Error)
  }
  self.checked_field_from_symbol(
    base,
    algebra.type_,
    algebra.effect,
    field.symbol,
    name,
    loc,
    loc,
  )
}

///|
fn SemanticChecker::apply_shape_algebra_operation(
  self : SemanticChecker,
  scope : TypeScope,
  algebra : CheckedExpressionSynthesis,
  name : String,
  arguments : Array[CheckedExpressionSynthesis],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let callee = self.checked_shape_algebra_field(algebra, name, loc)
  guard self.instantiate_generated_callable(
      scope,
      callee.type_,
      arguments,
      expected_result,
      "Shape algebra operation `\{name}`",
      loc,
    )
    is Some(instantiated) else {
    return checked_expression_none_reported(Error)
  }
  guard instantiated.parameters.length() == arguments.length() else {
    self.diagnostics.push({
      kind: CallArityMismatch(
        expected=instantiated.parameters.length(),
        actual=arguments.length(),
      ),
      loc,
    })
    return checked_expression_none_reported(instantiated.result)
  }
  let checked_arguments : Array[@checked.CheckedCallArgument] = []
  let effects = [callee.effect, instantiated.effect]
  for index in 0..<arguments.length() {
    if self.type_matches(
        instantiated.parameters[index],
        arguments[index].type_,
        loc,
      )
      is Some(false) {
      self.diagnostics.push({
        kind: TypeMismatch(
          expected=instantiated.parameters[index],
          actual=arguments[index].type_,
        ),
        loc,
      })
      return checked_expression_none_reported(instantiated.result)
    }
    guard self.require_checked_expression(
        arguments[index],
        loc,
        "Shape algebra argument",
      )
      is Some(value) else {
      return checked_expression_none_reported(instantiated.result)
    }
    checked_arguments.push({ value, loc })
    effects.push(arguments[index].effect)
  }
  guard self.require_checked_expression(callee, loc, "Shape algebra operation")
    is Some(callee_expression) else {
    return checked_expression_none_reported(instantiated.result)
  }
  let callee_expression = generic_applied_callee(
    callee_expression,
    instantiated.generic_arguments,
    Function(instantiated.parameters, instantiated.result, instantiated.effect),
    loc,
  )
  checked_expression_with_effect(
    Call(
      callee=callee_expression,
      arguments=checked_arguments,
      type_=instantiated.result,
      loc~,
    ),
    instantiated.result,
    effect_union(effects),
  )
}

///|
fn SemanticChecker::instantiate_generated_callable(
  self : SemanticChecker,
  scope : TypeScope,
  callable : @types.Type,
  arguments : Array[CheckedExpressionSynthesis],
  expected_result : @types.Type?,
  label : String,
  loc : SourceSpan,
) -> InstantiatedCallableType? {
  match callable {
    Function(parameters, result, effect) =>
      Some({ generic_arguments: [], parameters, result, effect })
    Forall(type_parameters, Function(parameters, result, effect)) => {
      let inference = GenericArgumentInference::GenericArgumentInference(
        self.declarations,
        scope,
        type_parameters,
      )
      let mut failed = false
      if expected_result is Some(expected) &&
        !inference.collect(result, expected) {
        failed = true
      }
      let count = if parameters.length() < arguments.length() {
        parameters.length()
      } else {
        arguments.length()
      }
      for index in 0..<count {
        if !inference.collect(parameters[index], arguments[index].type_) {
          failed = true
        }
      }
      if inference.computation_error is Some(error) {
        report_type_computation_failure(self.diagnostics, label, loc, error)
        return None
      }
      if inference.missing_kind_metadata is Some(_) {
        self.report_internal_typecheck_failure(
          "missing kind metadata while checking \{label}",
          loc,
        )
        return None
      }
      if failed {
        self.report_generic_argument_inference_failure(label, inference, loc)
        return None
      }
      guard inference.finish() is Some(inferred) else {
        self.report_generic_argument_inference_failure(label, inference, loc)
        return None
      }
      Some({
        generic_arguments: inferred.generic_arguments,
        parameters: parameters.map(fn(parameter) {
          parameter.substitute(inferred.substitution)
        }),
        result: result.substitute(inferred.substitution),
        effect: effect.substitute(inferred.substitution),
      })
    }
    _ => {
      self.diagnostics.push({ kind: NotCallable(callable), loc })
      None
    }
  }
}

///|
fn checked_string_literal(
  value : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  checked_expression(
    Literal(literal=String(value), type_=Primitive(String), loc~),
    Primitive(String),
  )
}

///|
fn checked_unit_literal(loc : SourceSpan) -> CheckedExpressionSynthesis {
  checked_expression(
    Literal(literal=Unit, type_=Primitive(Unit), loc~),
    Primitive(Unit),
  )
}

///|
fn checked_function_literal(
  parameter_symbol : ValueSymbolId,
  parameter_name : String,
  parameter_type : @types.Type,
  result_type : @types.Type,
  body : @checked.CheckedExpr,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let function_type = @types.Type::Function(
    [parameter_type],
    result_type,
    Empty,
  )
  checked_expression(
    FunctionLiteral(
      type_parameters=[],
      parameters=[
        {
          symbol: parameter_symbol,
          is_auto: false,
          is_offered: false,
          name: parameter_name,
          name_loc: loc,
          type_: parameter_type,
          loc,
        },
      ],
      return_type=result_type,
      body~,
      type_=function_type,
      loc~,
    ),
    function_type,
  )
}

///|
fn SemanticChecker::checked_struct_to_representation(
  self : SemanticChecker,
  target : @types.Type,
  declaration : CheckedStructDeclaration,
  representation : ShapeProductRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let parameter_symbol = self.resolved_source.symbols.define_value(
    "$shape_value",
    Parameter,
    loc,
  )
  let parameter = checked_expression(
    Value(name="$shape_value", symbol=parameter_symbol, type_=target, loc~),
    target,
  )
  let components = []
  for field in declaration.fields {
    guard self.require_checked_expression(parameter, loc, "Shape value")
      is Some(base) else {
      return checked_expression_none_reported(Error)
    }
    components.push(
      self.checked_field_from_symbol(
        base,
        target,
        Empty,
        field.symbol,
        field.name,
        loc,
        loc,
      ),
    )
  }
  let body = self.checked_product_value(components, representation, loc)
  guard self.require_checked_expression(body, loc, "Shape projection")
    is Some(body) else {
    return checked_expression_none_reported(Error)
  }
  checked_function_literal(
    parameter_symbol,
    "$shape_value",
    target,
    representation.type_,
    body,
    loc,
  )
}

///|
fn SemanticChecker::checked_struct_from_representation(
  self : SemanticChecker,
  target : @types.Type,
  declaration : CheckedStructDeclaration,
  representation : ShapeProductRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let parameter_symbol = self.resolved_source.symbols.define_value(
    "$shape_repr",
    Parameter,
    loc,
  )
  let parameter = checked_expression(
    Value(
      name="$shape_repr",
      symbol=parameter_symbol,
      type_=representation.type_,
      loc~,
    ),
    representation.type_,
  )
  guard self.checked_product_components(parameter, representation, loc)
    is Some(components) &&
    checked_nominal_arguments(target, self.diagnostics, loc)
    is Some((symbol, generic_arguments)) else {
    return checked_expression_none_reported(Error)
  }
  let fields : Array[@checked.CheckedStructLiteralField] = []
  for index in 0..<declaration.fields.length() {
    guard self.require_checked_expression(
        components[index],
        loc,
        "Shape reconstruction field",
      )
      is Some(value) else {
      return checked_expression_none_reported(Error)
    }
    fields.push({
      symbol: declaration.fields[index].symbol,
      name: declaration.fields[index].name,
      value,
      loc,
    })
  }
  let body = @checked.CheckedExpr::StructLiteral(
    symbol~,
    type_name_loc=loc,
    generic_arguments~,
    type_witnesses=[],
    fields~,
    type_=target,
    loc~,
  )
  checked_function_literal(
    parameter_symbol,
    "$shape_repr",
    representation.type_,
    target,
    body,
    loc,
  )
}

///|
fn SemanticChecker::checked_product_value(
  self : SemanticChecker,
  components : Array[CheckedExpressionSynthesis],
  representation : ShapeProductRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let mut tail = checked_unit_literal(loc)
  for index = components.length() - 1; index >= 0; index = index - 1 {
    tail = self.checked_binary_struct_value(
      representation.pair_types[index],
      components[index],
      tail,
      loc,
    )
  }
  tail
}

///|
fn SemanticChecker::checked_product_components(
  self : SemanticChecker,
  product : CheckedExpressionSynthesis,
  representation : ShapeProductRepresentation,
  loc : SourceSpan,
) -> Array[CheckedExpressionSynthesis]? {
  let components = []
  let mut tail = product
  for pair_type in representation.pair_types {
    guard self.checked_binary_struct_fields(tail, pair_type, loc)
      is Some((head, next)) else {
      return None
    }
    components.push(head)
    tail = next
  }
  Some(components)
}

///|
fn SemanticChecker::checked_binary_struct_value(
  self : SemanticChecker,
  type_ : @types.Type,
  first : CheckedExpressionSynthesis,
  second : CheckedExpressionSynthesis,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard checked_nominal_arguments(type_, self.diagnostics, loc)
    is Some((symbol, generic_arguments)) &&
    self.declarations.checked_struct(symbol) is Some(declaration) &&
    declaration.type_members.is_empty() &&
    declaration.fields is [first_field, second_field] &&
    self.require_checked_expression(first, loc, "Shape product head")
    is Some(first) &&
    self.require_checked_expression(second, loc, "Shape product tail")
    is Some(second) else {
    self.diagnostics.push({
      kind: InvalidShapeAlgebraRepresentation(operation="product", type_),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  checked_expression(
    StructLiteral(
      symbol~,
      type_name_loc=loc,
      generic_arguments~,
      type_witnesses=[],
      fields=[
        {
          symbol: first_field.symbol,
          name: first_field.name,
          value: first,
          loc,
        },
        {
          symbol: second_field.symbol,
          name: second_field.name,
          value: second,
          loc,
        },
      ],
      type_~,
      loc~,
    ),
    type_,
  )
}

///|
fn SemanticChecker::checked_binary_struct_fields(
  self : SemanticChecker,
  value : CheckedExpressionSynthesis,
  type_ : @types.Type,
  loc : SourceSpan,
) -> (CheckedExpressionSynthesis, CheckedExpressionSynthesis)? {
  guard checked_nominal_arguments(type_, self.diagnostics, loc)
    is Some((symbol, _)) &&
    self.declarations.checked_struct(symbol) is Some(declaration) &&
    declaration.fields is [first, second] &&
    self.require_checked_expression(value, loc, "Shape product") is Some(base) else {
    self.diagnostics.push({
      kind: InvalidShapeAlgebraRepresentation(operation="product", type_),
      loc,
    })
    return None
  }
  Some(
    (
      self.checked_field_from_symbol(
        base,
        type_,
        value.effect,
        first.symbol,
        first.name,
        loc,
        loc,
      ),
      self.checked_field_from_symbol(
        base,
        type_,
        value.effect,
        second.symbol,
        second.name,
        loc,
        loc,
      ),
    ),
  )
}

///|
fn SemanticChecker::checked_enum_to_representation(
  self : SemanticChecker,
  target : @types.Type,
  _declaration : CheckedEnumDeclaration,
  representation : ShapeSumRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let parameter_symbol = self.resolved_source.symbols.define_value(
    "$shape_value",
    Parameter,
    loc,
  )
  let scrutinee = @checked.CheckedExpr::Value(
    name="$shape_value",
    symbol=parameter_symbol,
    type_=target,
    loc~,
  )
  let arms : Array[@checked.CheckedMatchArm] = []
  for variant_index in 0..<representation.variants.length() {
    let variant = representation.variants[variant_index]
    let payload_patterns = []
    let payload_values = []
    for payload_index in 0..<variant.payload_types.length() {
      let symbol = self.resolved_source.symbols.define_value(
        "$shape_payload",
        PatternBinder,
        loc,
      )
      let type_ = variant.payload_types[payload_index]
      payload_patterns.push(
        @checked.CheckedPattern::Binding(
          name="$shape_payload",
          symbol~,
          type_~,
          loc~,
        ),
      )
      payload_values.push(
        checked_expression(
          Value(name="$shape_payload", symbol~, type_~, loc~),
          type_,
        ),
      )
    }
    let product = self.checked_product_value(
      payload_values,
      variant.product,
      loc,
    )
    let body = self.checked_sum_value(
      product, variant_index, representation, loc,
    )
    guard self.require_checked_expression(body, loc, "Shape enum projection")
      is Some(body) else {
      return checked_expression_none_reported(Error)
    }
    arms.push({
      pattern: Variant(
        symbol=variant.declaration.symbol,
        variant_loc=loc,
        generic_arguments=[],
        arguments=payload_patterns,
        type_=target,
        loc~,
      ),
      body,
      loc,
    })
  }
  let body = @checked.CheckedExpr::Match(
    scrutinee~,
    arms~,
    type_=representation.type_,
    loc~,
  )
  checked_function_literal(
    parameter_symbol,
    "$shape_value",
    target,
    representation.type_,
    body,
    loc,
  )
}

///|
fn SemanticChecker::checked_enum_from_representation(
  self : SemanticChecker,
  target : @types.Type,
  _declaration : CheckedEnumDeclaration,
  representation : ShapeSumRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let parameter_symbol = self.resolved_source.symbols.define_value(
    "$shape_repr",
    Parameter,
    loc,
  )
  let scrutinee = @checked.CheckedExpr::Value(
    name="$shape_repr",
    symbol=parameter_symbol,
    type_=representation.type_,
    loc~,
  )
  let arms : Array[@checked.CheckedMatchArm] = []
  for variant_index in 0..<representation.variants.length() {
    let variant = representation.variants[variant_index]
    let payload_symbol = self.resolved_source.symbols.define_value(
      "$shape_variant",
      PatternBinder,
      loc,
    )
    let payload_value = checked_expression(
      Value(
        name="$shape_variant",
        symbol=payload_symbol,
        type_=variant.product.type_,
        loc~,
      ),
      variant.product.type_,
    )
    guard self.checked_product_components(payload_value, variant.product, loc)
      is Some(components) else {
      return checked_expression_none_reported(Error)
    }
    let arguments = []
    for component in components {
      guard self.require_checked_expression(
          component, loc, "Shape enum reconstruction payload",
        )
        is Some(component) else {
        return checked_expression_none_reported(Error)
      }
      arguments.push(component)
    }
    let pattern = self.checked_sum_pattern(
      Binding(
        name="$shape_variant",
        symbol=payload_symbol,
        type_=variant.product.type_,
        loc~,
      ),
      variant_index,
      representation,
      loc,
    )
    arms.push({
      pattern,
      body: Variant(
        symbol=variant.declaration.symbol,
        variant_loc=loc,
        generic_arguments=[],
        arguments~,
        type_=target,
        loc~,
      ),
      loc,
    })
  }
  let body = @checked.CheckedExpr::Match(scrutinee~, arms~, type_=target, loc~)
  checked_function_literal(
    parameter_symbol,
    "$shape_repr",
    representation.type_,
    target,
    body,
    loc,
  )
}

///|
fn SemanticChecker::checked_sum_value(
  self : SemanticChecker,
  payload : CheckedExpressionSynthesis,
  variant_index : Int,
  representation : ShapeSumRepresentation,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let mut result = payload
  if variant_index < representation.sum_types.length() {
    result = self.checked_sum_variant_value(
      representation.sum_types[variant_index],
      0,
      result,
      loc,
    )
  }
  for index = variant_index - 1; index >= 0; index = index - 1 {
    result = self.checked_sum_variant_value(
      representation.sum_types[index],
      1,
      result,
      loc,
    )
  }
  result
}

///|
fn SemanticChecker::checked_sum_variant_value(
  self : SemanticChecker,
  sum_type : @types.Type,
  variant_index : Int,
  payload : CheckedExpressionSynthesis,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard checked_nominal_arguments(sum_type, self.diagnostics, loc)
    is Some((symbol, _)) &&
    self.declarations.checked_enum(symbol) is Some(declaration) &&
    declaration.variants is [left, right] else {
    self.diagnostics.push({
      kind: InvalidShapeAlgebraRepresentation(operation="sum", sum_type),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  let variant = if variant_index == 0 { left } else { right }
  guard variant.type_parameters.is_empty() &&
    variant.payload.length() == 1 &&
    self.require_checked_expression(payload, loc, "Shape sum payload")
    is Some(payload) else {
    self.diagnostics.push({
      kind: InvalidShapeAlgebraRepresentation(operation="sum", sum_type),
      loc,
    })
    return checked_expression_none_reported(Error)
  }
  checked_expression(
    Variant(
      symbol=variant.symbol,
      variant_loc=loc,
      generic_arguments=[],
      arguments=[payload],
      type_=sum_type,
      loc~,
    ),
    sum_type,
  )
}

///|
fn SemanticChecker::checked_sum_pattern(
  self : SemanticChecker,
  payload : @checked.CheckedPattern,
  variant_index : Int,
  representation : ShapeSumRepresentation,
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  let mut result = payload
  if variant_index < representation.sum_types.length() {
    result = self.checked_sum_variant_pattern(
      representation.sum_types[variant_index],
      0,
      result,
      loc,
    )
  }
  for index = variant_index - 1; index >= 0; index = index - 1 {
    result = self.checked_sum_variant_pattern(
      representation.sum_types[index],
      1,
      result,
      loc,
    )
  }
  result
}

///|
fn SemanticChecker::checked_sum_variant_pattern(
  self : SemanticChecker,
  sum_type : @types.Type,
  variant_index : Int,
  payload : @checked.CheckedPattern,
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  guard checked_nominal_arguments(sum_type, self.diagnostics, loc)
    is Some((symbol, _)) &&
    self.declarations.checked_enum(symbol) is Some(declaration) &&
    declaration.variants is [left, right] else {
    self.diagnostics.push({
      kind: InvalidShapeAlgebraRepresentation(operation="sum", sum_type),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let variant = if variant_index == 0 { left } else { right }
  Variant(
    symbol=variant.symbol,
    variant_loc=loc,
    generic_arguments=[],
    arguments=[payload],
    type_=sum_type,
    loc~,
  )
}

///|
fn checked_nominal_arguments(
  type_ : @types.Type,
  diagnostics : Array[TypeCheckDiagnostic],
  loc : SourceSpan,
) -> (TypeSymbolId, Array[@types.GenericArgument])? {
  match
    decompose_nominal_or_report(
      diagnostics,
      type_,
      loc,
      context="generated Shape representation",
    ) {
    Nominal(symbol, arguments) => Some((symbol, arguments))
    _ => None
  }
}
