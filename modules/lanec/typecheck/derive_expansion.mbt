///|
fn SemanticChecker::build_structural_derive_iso(
  self : SemanticChecker,
  abi : StructuralDeriveAbi,
  target_type : @types.Type,
  target : StructuralDeriveTarget,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let representation = target.representation()
  let to_function = self.build_structural_derive_to_function(
    abi, target_type, target, loc,
  )
  let from_function = self.build_structural_derive_from_function(
    abi, target_type, target, loc,
  )
  checked_struct_value(
    abi.iso,
    [TypeArgument(target_type), TypeArgument(representation)],
    [to_function, from_function],
    @types.nominal_type(abi.iso.symbol, [target_type, representation]),
    loc,
  )
}

///|
fn SemanticChecker::build_structural_derive_to_function(
  self : SemanticChecker,
  abi : StructuralDeriveAbi,
  target_type : @types.Type,
  target : StructuralDeriveTarget,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let parameter = self.generated_derive_parameter(
    "_derive_value", target_type, loc,
  )
  let value = checked_parameter_value(parameter)
  let body = match target {
    RecordTarget(fields~, ..) => {
      let values = fields.map(fn(field) {
        @checked.CheckedExpr::Field(
          base=value,
          field=field.symbol,
          name=field.name,
          name_loc=loc,
          type_=field.type_,
          loc~,
        )
      })
      checked_product_value(
        abi,
        values,
        fields.map(fn(field) { field.type_ }),
        loc,
      )
    }
    EnumerationTarget(variants~, representation~, ..) => {
      let sum_types = sum_suffix_types(abi, variants)
      let arms : Array[@checked.CheckedMatchArm] = []
      for index in 0..<variants.length() {
        let variant = variants[index]
        let parameters = variant.payload.map(fn(type_) {
          self.generated_derive_parameter("_derive_payload", type_, loc)
        })
        let payload = checked_product_value(
          abi,
          parameters.map(checked_parameter_value),
          variant.payload,
          loc,
        )
        arms.push({
          pattern: Variant(
            symbol=variant.symbol,
            variant_loc=loc,
            generic_arguments=[],
            arguments=parameters.map(fn(parameter) {
              Binding(
                name=parameter.name,
                symbol=parameter.symbol,
                type_=parameter.type_,
                loc~,
              )
            }),
            type_=target_type,
            loc~,
          ),
          body: checked_sum_injection(
            abi, variants, index, 0, payload, sum_types, loc,
          ),
          loc,
        })
      }
      Match(scrutinee=value, arms~, type_=representation, loc~)
    }
  }
  checked_function_value([parameter], target.representation(), body, loc)
}

///|
fn SemanticChecker::build_structural_derive_from_function(
  self : SemanticChecker,
  abi : StructuralDeriveAbi,
  target_type : @types.Type,
  target : StructuralDeriveTarget,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let representation = target.representation()
  let parameter = self.generated_derive_parameter(
    "_derive_representation", representation, loc,
  )
  let value = checked_parameter_value(parameter)
  let body = match target {
    RecordTarget(declaration~, arguments~, fields~, ..) =>
      checked_struct_value(
        declaration,
        arguments,
        checked_product_projections(
          abi,
          value,
          fields.map(fn(field) { field.type_ }),
          loc,
        ),
        target_type,
        loc,
      )
    EnumerationTarget(variants~, ..) => {
      let sum_types = sum_suffix_types(abi, variants)
      let arms : Array[@checked.CheckedMatchArm] = []
      for index in 0..<variants.length() {
        let variant = variants[index]
        let payload_parameters = variant.payload.map(fn(type_) {
          self.generated_derive_parameter("_derive_payload", type_, loc)
        })
        arms.push({
          pattern: checked_sum_pattern(
            abi, variants, index, 0, payload_parameters, sum_types, loc,
          ),
          body: Variant(
            symbol=variant.symbol,
            variant_loc=loc,
            generic_arguments=[],
            arguments=payload_parameters.map(checked_parameter_value),
            type_=target_type,
            loc~,
          ),
          loc,
        })
      }
      let impossible = self.generated_derive_parameter(
        "_derive_impossible",
        Constructor(abi.void_declaration.symbol),
        loc,
      )
      arms.push({
        pattern: checked_sum_void_pattern(
          abi, variants, 0, sum_types, impossible, loc,
        ),
        body: Match(
          scrutinee=checked_parameter_value(impossible),
          arms=[],
          type_=target_type,
          loc~,
        ),
        loc,
      })
      Match(scrutinee=value, arms~, type_=target_type, loc~)
    }
  }
  checked_function_value([parameter], target_type, body, loc)
}

///|
fn checked_sum_void_pattern(
  abi : StructuralDeriveAbi,
  variants : Array[StructuralDeriveVariant],
  index : Int,
  sum_types : Array[@types.Type],
  impossible : @checked.CheckedValueParameter,
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  if index == variants.length() {
    return Binding(
      name=impossible.name,
      symbol=impossible.symbol,
      type_=impossible.type_,
      loc~,
    )
  }
  Variant(
    symbol=abi.sum.required_variant("there").symbol,
    variant_loc=loc,
    generic_arguments=[],
    arguments=[
      checked_sum_void_pattern(
        abi,
        variants,
        index + 1,
        sum_types,
        impossible,
        loc,
      ),
    ],
    type_=sum_types[index],
    loc~,
  )
}

///|
fn SemanticChecker::generated_derive_parameter(
  self : SemanticChecker,
  name : String,
  type_ : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedValueParameter {
  {
    symbol: self.resolved_source.symbols.define_generated_local(name, loc),
    is_auto: false,
    is_offered: false,
    name,
    name_loc: loc,
    type_,
    loc,
  }
}

///|
fn checked_parameter_value(
  parameter : @checked.CheckedValueParameter,
) -> @checked.CheckedExpr {
  Value(
    name=parameter.name,
    symbol=parameter.symbol,
    type_=parameter.type_,
    loc=parameter.loc,
  )
}

///|
fn checked_function_value(
  parameters : Array[@checked.CheckedValueParameter],
  result : @types.Type,
  body : @checked.CheckedExpr,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let type_ = @types.Type::Function(
    parameters.map(fn(parameter) { parameter.type_ }),
    result,
    Empty,
  )
  FunctionLiteral(
    type_parameters=[],
    parameters~,
    return_type=result,
    body~,
    type_~,
    loc~,
  )
}

///|
fn checked_struct_value(
  declaration : CheckedStructDeclaration,
  generic_arguments : Array[@types.GenericArgument],
  values : Array[@checked.CheckedExpr],
  type_ : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let fields : Array[@checked.CheckedStructLiteralField] = []
  for index in 0..<declaration.fields.length() {
    let field = declaration.fields[index]
    fields.push({
      symbol: field.symbol,
      name: field.name,
      value: values[index],
      loc,
    })
  }
  StructLiteral(
    symbol=declaration.symbol,
    type_name_loc=loc,
    generic_arguments~,
    type_witnesses=[],
    fields~,
    type_~,
    loc~,
  )
}

///|
fn checked_product_value(
  abi : StructuralDeriveAbi,
  values : Array[@checked.CheckedExpr],
  types : Array[@types.Type],
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let mut result : @checked.CheckedExpr = Literal(
    literal=Unit,
    type_=Primitive(Unit),
    loc~,
  )
  let mut result_type = @types.Type::Primitive(Unit)
  for index = values.length() - 1; index >= 0; index = index - 1 {
    let product_type = @types.nominal_type(abi.product.symbol, [
      types[index],
      result_type,
    ])
    result = checked_struct_value(
      abi.product,
      [TypeArgument(types[index]), TypeArgument(result_type)],
      [values[index], result],
      product_type,
      loc,
    )
    result_type = product_type
  }
  result
}

///|
fn checked_product_projections(
  abi : StructuralDeriveAbi,
  value : @checked.CheckedExpr,
  types : Array[@types.Type],
  loc : SourceSpan,
) -> Array[@checked.CheckedExpr] {
  let suffix_types = product_suffix_types(abi, types)
  let result : Array[@checked.CheckedExpr] = []
  let mut current = value
  for index in 0..<types.length() {
    result.push(
      Field(
        base=current,
        field=abi.product.required_field("head").symbol,
        name="head",
        name_loc=loc,
        type_=types[index],
        loc~,
      ),
    )
    let next_tail_type = suffix_types[index + 1]
    current = Field(
      base=current,
      field=abi.product.required_field("tail").symbol,
      name="tail",
      name_loc=loc,
      type_=next_tail_type,
      loc~,
    )
  }
  result
}

///|
fn checked_sum_injection(
  abi : StructuralDeriveAbi,
  variants : Array[StructuralDeriveVariant],
  target_index : Int,
  current_index : Int,
  payload : @checked.CheckedExpr,
  sum_types : Array[@types.Type],
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  if current_index == target_index {
    return Variant(
      symbol=abi.sum.required_variant("here").symbol,
      variant_loc=loc,
      generic_arguments=[],
      arguments=[payload],
      type_=sum_types[current_index],
      loc~,
    )
  }
  Variant(
    symbol=abi.sum.required_variant("there").symbol,
    variant_loc=loc,
    generic_arguments=[],
    arguments=[
      checked_sum_injection(
        abi,
        variants,
        target_index,
        current_index + 1,
        payload,
        sum_types,
        loc,
      ),
    ],
    type_=sum_types[current_index],
    loc~,
  )
}

///|
fn checked_sum_pattern(
  abi : StructuralDeriveAbi,
  variants : Array[StructuralDeriveVariant],
  target_index : Int,
  current_index : Int,
  payload_parameters : Array[@checked.CheckedValueParameter],
  sum_types : Array[@types.Type],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  if current_index == target_index {
    return Variant(
      symbol=abi.sum.required_variant("here").symbol,
      variant_loc=loc,
      generic_arguments=[],
      arguments=[checked_product_pattern(abi, payload_parameters, loc)],
      type_=sum_types[current_index],
      loc~,
    )
  }
  Variant(
    symbol=abi.sum.required_variant("there").symbol,
    variant_loc=loc,
    generic_arguments=[],
    arguments=[
      checked_sum_pattern(
        abi,
        variants,
        target_index,
        current_index + 1,
        payload_parameters,
        sum_types,
        loc,
      ),
    ],
    type_=sum_types[current_index],
    loc~,
  )
}

///|
fn checked_product_pattern(
  abi : StructuralDeriveAbi,
  parameters : Array[@checked.CheckedValueParameter],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  checked_product_pattern_from(
    abi,
    parameters,
    0,
    product_suffix_types(abi, parameters.map(fn(parameter) { parameter.type_ })),
    loc,
  )
}

///|
fn checked_product_pattern_from(
  abi : StructuralDeriveAbi,
  parameters : Array[@checked.CheckedValueParameter],
  index : Int,
  suffix_types : Array[@types.Type],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  if index == parameters.length() {
    return Literal(literal=Unit, type_=Primitive(Unit), loc~)
  }
  let parameter = parameters[index]
  Struct(
    symbol=abi.product.symbol,
    type_name_loc=loc,
    type_binders=[],
    fields=[
      {
        symbol: abi.product.required_field("head").symbol,
        name: "head",
        pattern: Binding(
          name=parameter.name,
          symbol=parameter.symbol,
          type_=parameter.type_,
          loc~,
        ),
        loc,
      },
      {
        symbol: abi.product.required_field("tail").symbol,
        name: "tail",
        pattern: checked_product_pattern_from(
          abi,
          parameters,
          index + 1,
          suffix_types,
          loc,
        ),
        loc,
      },
    ],
    type_=suffix_types[index],
    loc~,
  )
}

///|
fn SemanticChecker::build_structural_derive_expansion(
  self : SemanticChecker,
  abi : StructuralDeriveAbi,
  capability : @types.Type,
  target_type : @types.Type,
  target : StructuralDeriveTarget,
  deriver : @checked.CheckedExpr,
  evidence : Array[@checked.CheckedDeriveEvidence],
  iso : @checked.CheckedExpr,
  result_type : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let deriver_type = @types.nominal_type_generic(abi.deriver.symbol, [
    TypeArgument(capability),
  ])
  let deriver_symbol = self.resolved_source.symbols.define_generated_local(
    "_derive_deriver", loc,
  )
  let deriver_ref : @checked.CheckedExpr = Value(
    name="_derive_deriver",
    symbol=deriver_symbol,
    type_=deriver_type,
    loc~,
  )
  let body = match target {
    RecordTarget(fields~, ..) => {
      let mut derived = call_deriver_method(
        abi,
        capability,
        deriver_ref,
        "unit",
        [],
        [],
        apply_unary_type_constructor(capability, Primitive(Unit)),
        loc,
      )
      let mut tail_type = @types.Type::Primitive(Unit)
      for index = fields.length() - 1; index >= 0; index = index - 1 {
        let field = fields[index]
        let required = apply_unary_type_constructor(capability, field.type_)
        let field_value = call_deriver_method(
          abi,
          capability,
          deriver_ref,
          "field",
          [TypeArgument(field.type_)],
          [
            checked_metadata_value(abi.field_info, [field.name], loc),
            derive_evidence_value(evidence, index),
          ],
          required,
          loc,
        )
        let product_type = @types.nominal_type(abi.product.symbol, [
          field.type_,
          tail_type,
        ])
        derived = call_deriver_method(
          abi,
          capability,
          deriver_ref,
          "product",
          [TypeArgument(field.type_), TypeArgument(tail_type)],
          [field_value, derived],
          apply_unary_type_constructor(capability, product_type),
          loc,
        )
        tail_type = product_type
      }
      call_deriver_method(
        abi,
        capability,
        deriver_ref,
        "record",
        [TypeArgument(target_type), TypeArgument(target.representation())],
        [checked_type_info_value(abi, target.metadata(), loc), iso, derived],
        result_type,
        loc,
      )
    }
    EnumerationTarget(variants~, ..) => {
      let evidence_offsets = []
      let mut evidence_offset = 0
      for variant in variants {
        evidence_offsets.push(evidence_offset)
        evidence_offset += variant.payload.length()
      }
      let mut derived = call_deriver_method(
        abi,
        capability,
        deriver_ref,
        "void",
        [],
        [],
        apply_unary_type_constructor(
          capability,
          Constructor(abi.void_declaration.symbol),
        ),
        loc,
      )
      let mut tail_type = @types.Type::Constructor(abi.void_declaration.symbol)
      for variant_index = variants.length() - 1
          variant_index >= 0
          variant_index = variant_index - 1 {
        let variant = variants[variant_index]
        let mut payload_derived = call_deriver_method(
          abi,
          capability,
          deriver_ref,
          "unit",
          [],
          [],
          apply_unary_type_constructor(capability, Primitive(Unit)),
          loc,
        )
        let mut payload_tail_type = @types.Type::Primitive(Unit)
        for payload_index = variant.payload.length() - 1
            payload_index >= 0
            payload_index = payload_index - 1 {
          let payload_type = variant.payload[payload_index]
          let product_type = @types.nominal_type(abi.product.symbol, [
            payload_type, payload_tail_type,
          ])
          payload_derived = call_deriver_method(
            abi,
            capability,
            deriver_ref,
            "product",
            [TypeArgument(payload_type), TypeArgument(payload_tail_type)],
            [
              derive_evidence_value(
                evidence,
                evidence_offsets[variant_index] + payload_index,
              ),
              payload_derived,
            ],
            apply_unary_type_constructor(capability, product_type),
            loc,
          )
          payload_tail_type = product_type
        }
        let variant_derived = call_deriver_method(
          abi,
          capability,
          deriver_ref,
          "variant",
          [TypeArgument(payload_tail_type)],
          [
            checked_metadata_value(abi.variant_info, [variant.name], loc),
            payload_derived,
          ],
          apply_unary_type_constructor(capability, payload_tail_type),
          loc,
        )
        let sum_type = @types.nominal_type(abi.sum.symbol, [
          payload_tail_type, tail_type,
        ])
        derived = call_deriver_method(
          abi,
          capability,
          deriver_ref,
          "sum",
          [TypeArgument(payload_tail_type), TypeArgument(tail_type)],
          [variant_derived, derived],
          apply_unary_type_constructor(capability, sum_type),
          loc,
        )
        tail_type = sum_type
      }
      call_deriver_method(
        abi,
        capability,
        deriver_ref,
        "enumeration",
        [TypeArgument(target_type), TypeArgument(target.representation())],
        [checked_type_info_value(abi, target.metadata(), loc), iso, derived],
        result_type,
        loc,
      )
    }
  }
  Block(
    items=[
      Let({
        is_public: false,
        is_offered: false,
        symbol: deriver_symbol,
        name: "_derive_deriver",
        name_loc: loc,
        initializer: deriver,
        type_: deriver_type,
        loc,
      }),
    ],
    result=body,
    type_=result_type,
    loc~,
  )
}

///|
fn call_deriver_method(
  abi : StructuralDeriveAbi,
  capability : @types.Type,
  deriver : @checked.CheckedExpr,
  name : String,
  generic_arguments : Array[@types.GenericArgument],
  arguments : Array[@checked.CheckedExpr],
  result_type : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  let field = abi.deriver.required_field(name)
  let substitution = abi.deriver.nominal_substitution([TypeArgument(capability)])
  let mut callee : @checked.CheckedExpr = Field(
    base=deriver,
    field=field.symbol,
    name~,
    name_loc=loc,
    type_=field.type_.substitute(substitution),
    loc~,
  )
  if !generic_arguments.is_empty() {
    guard callee.type_() is Forall(parameters, body) else {
      abort("validated generic deriver method is not polymorphic")
    }
    let generic_substitution = @types.TypeSubstitution::TypeSubstitution()
    for index in 0..<parameters.length() {
      generic_substitution.insert_argument(
        parameters[index].id,
        generic_arguments[index],
      )
    }
    callee = GenericApplication(
      callee~,
      arguments=generic_arguments,
      type_=body.substitute(generic_substitution),
      loc~,
    )
  }
  Call(
    callee~,
    arguments=arguments.map(fn(value) { { value, loc } }),
    type_=result_type,
    loc~,
  )
}

///|
fn checked_type_info_value(
  abi : StructuralDeriveAbi,
  metadata : @checked.CheckedDeriveMetadata,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  checked_metadata_value(
    abi.type_info,
    [metadata.name, metadata.qualified_name],
    loc,
  )
}

///|
fn checked_metadata_value(
  declaration : CheckedStructDeclaration,
  values : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  checked_struct_value(
    declaration,
    [],
    values.map(fn(value) {
      Literal(literal=String(value), type_=Primitive(String), loc~)
    }),
    Constructor(declaration.symbol),
    loc,
  )
}

///|
fn derive_evidence_value(
  evidence : Array[@checked.CheckedDeriveEvidence],
  index : Int,
) -> @checked.CheckedExpr {
  if evidence.get(index) is Some(value) {
    return value.value
  }
  abort("checked structural derivation evidence is incomplete")
}
